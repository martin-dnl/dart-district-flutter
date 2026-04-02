import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Friendship } from './entities/friendship.entity';
import { User } from '../users/entities/user.entity';
import { DirectMessage } from '../realtime/entities/direct-message.entity';
import {
  FriendRequest,
  FriendRequestStatus,
} from './entities/friend-request.entity';
import { UserBlock } from './entities/user-block.entity';
import { normalizeLimit } from '../../common/utils/normalize-limit';

@Injectable()
export class ContactsService {
  constructor(
    @InjectRepository(Friendship)
    private readonly friendshipRepo: Repository<Friendship>,
    @InjectRepository(FriendRequest)
    private readonly friendRequestRepo: Repository<FriendRequest>,
    @InjectRepository(UserBlock)
    private readonly userBlockRepo: Repository<UserBlock>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(DirectMessage)
    private readonly dmRepo: Repository<DirectMessage>,
  ) {}

  async listIncomingRequests(userId: string) {
    const rows = await this.friendRequestRepo.find({
      where: {
        receiver_id: userId,
        status: FriendRequestStatus.PENDING,
      },
      relations: ['sender'],
      order: { created_at: 'DESC' },
    });

    return rows.map((req) => ({
      id: req.id,
      created_at: req.created_at,
      sender: this.mapFriend(req.sender),
    }));
  }

  async listOutgoingRequests(userId: string) {
    const rows = await this.friendRequestRepo.find({
      where: {
        sender_id: userId,
        status: FriendRequestStatus.PENDING,
      },
      relations: ['receiver'],
      order: { created_at: 'DESC' },
    });

    return rows.map((req) => ({
      id: req.id,
      created_at: req.created_at,
      receiver: this.mapFriend(req.receiver),
    }));
  }

  async sendFriendRequest(userId: string, receiverId: string) {
        const blockedBetweenUsers = await this.userBlockRepo.findOne({
          where: [
            { blocker_id: userId, blocked_id: receiverId },
            { blocker_id: receiverId, blocked_id: userId },
          ],
        });
        if (blockedBetweenUsers) {
          throw new ForbiddenException('Friend request unavailable for this user');
        }

    if (userId === receiverId) {
      throw new BadRequestException('You cannot send a friend request to yourself');
    }

    const receiver = await this.userRepo.findOne({ where: { id: receiverId } });
    if (!receiver) {
      throw new NotFoundException('Receiver user not found');
    }

    const alreadyFriends = await this.friendshipRepo.findOne({
      where: { user_id: userId, friend_id: receiverId },
    });
    if (alreadyFriends) {
      return {
        status: 'already_friends',
        friend: this.mapFriend(receiver),
      };
    }

    const existingOutgoing = await this.friendRequestRepo.findOne({
      where: {
        sender_id: userId,
        receiver_id: receiverId,
        status: FriendRequestStatus.PENDING,
      },
    });
    if (existingOutgoing) {
      return {
        status: 'pending',
        request_id: existingOutgoing.id,
      };
    }

    const reversePending = await this.friendRequestRepo.findOne({
      where: {
        sender_id: receiverId,
        receiver_id: userId,
        status: FriendRequestStatus.PENDING,
      },
      relations: ['sender'],
    });
    if (reversePending) {
      await this.acceptFriendRequest(userId, reversePending.id);
      return {
        status: 'accepted',
        friend: this.mapFriend(reversePending.sender),
      };
    }

    const created = await this.friendRequestRepo.save(
      this.friendRequestRepo.create({
        sender_id: userId,
        receiver_id: receiverId,
        status: FriendRequestStatus.PENDING,
      }),
    );

    return {
      status: 'pending',
      request_id: created.id,
    };
  }

  async acceptFriendRequest(userId: string, requestId: string) {
    const request = await this.friendRequestRepo.findOne({
      where: { id: requestId },
      relations: ['sender', 'receiver'],
    });
    if (!request) {
      throw new NotFoundException('Friend request not found');
    }

    if (request.receiver_id !== userId) {
      throw new ForbiddenException('You cannot accept this friend request');
    }

    if (request.status !== FriendRequestStatus.PENDING) {
      return {
        status: request.status,
        friend: this.mapFriend(request.sender),
      };
    }

    request.status = FriendRequestStatus.ACCEPTED;
    request.responded_at = new Date();
    await this.friendRequestRepo.save(request);

    await this.ensureFriendshipPair(request.sender_id, request.receiver_id);

    return {
      status: 'accepted',
      friend: this.mapFriend(request.sender),
    };
  }

  async rejectFriendRequest(userId: string, requestId: string) {
    const request = await this.friendRequestRepo.findOne({
      where: { id: requestId },
      relations: ['sender'],
    });
    if (!request) {
      throw new NotFoundException('Friend request not found');
    }

    if (request.receiver_id !== userId) {
      throw new ForbiddenException('You cannot reject this friend request');
    }

    if (request.status !== FriendRequestStatus.PENDING) {
      return { status: request.status };
    }

    request.status = FriendRequestStatus.REJECTED;
    request.responded_at = new Date();
    await this.friendRequestRepo.save(request);

    return { status: 'rejected' };
  }

  async listFriends(userId: string) {
    const rows = await this.friendshipRepo.find({
      where: { user_id: userId },
      relations: ['friend'],
      order: { created_at: 'DESC' },
    });

    return rows
      .map((row) => row.friend)
      .filter(Boolean)
      .map((friend) => ({
        id: friend.id,
        username: friend.username,
        avatar_url: friend.avatar_url,
        elo: friend.elo,
      }));
  }

  async addFriend(userId: string, friendId: string) {
    if (userId === friendId) {
      throw new BadRequestException('You cannot add yourself as a friend');
    }

    const friend = await this.userRepo.findOne({ where: { id: friendId } });
    if (!friend) {
      throw new NotFoundException('Friend user not found');
    }

    await this.ensureFriendshipPair(userId, friendId);

    return {
      id: friend.id,
      username: friend.username,
      avatar_url: friend.avatar_url,
      elo: friend.elo,
    };
  }

  async removeFriend(userId: string, friendId: string) {
    await this.friendshipRepo.delete([
      { user_id: userId, friend_id: friendId },
      { user_id: friendId, friend_id: userId },
    ]);
    return { success: true };
  }

  async blockUser(blockerId: string, blockedId: string) {
    if (blockerId === blockedId) {
      throw new BadRequestException('You cannot block yourself');
    }

    const target = await this.userRepo.findOne({ where: { id: blockedId } });
    if (!target) {
      throw new NotFoundException('User not found');
    }

    await this.friendshipRepo.delete([
      { user_id: blockerId, friend_id: blockedId },
      { user_id: blockedId, friend_id: blockerId },
    ]);

    await this.friendRequestRepo
      .createQueryBuilder()
      .update(FriendRequest)
      .set({ status: FriendRequestStatus.REJECTED, responded_at: () => 'NOW()' })
      .where(
        'status = :status AND ((sender_id = :blockerId AND receiver_id = :blockedId) OR (sender_id = :blockedId AND receiver_id = :blockerId))',
        {
          status: FriendRequestStatus.PENDING,
          blockerId,
          blockedId,
        },
      )
      .execute();

    const existing = await this.userBlockRepo.findOne({
      where: { blocker_id: blockerId, blocked_id: blockedId },
    });
    if (!existing) {
      await this.userBlockRepo.save(
        this.userBlockRepo.create({ blocker_id: blockerId, blocked_id: blockedId }),
      );
    }

    return { success: true };
  }

  async unblockUser(blockerId: string, blockedId: string) {
    await this.userBlockRepo.delete({ blocker_id: blockerId, blocked_id: blockedId });
    return { success: true };
  }

  async getFriendshipStatus(userId: string, targetId: string) {
    if (userId === targetId) {
      return {
        is_friend: false,
        is_blocked: false,
        has_pending_request: false,
      };
    }

    const [friendship, blockedByMe, blockedMe, pendingRequest] = await Promise.all([
      this.friendshipRepo.findOne({
        where: { user_id: userId, friend_id: targetId },
      }),
      this.userBlockRepo.findOne({
        where: { blocker_id: userId, blocked_id: targetId },
      }),
      this.userBlockRepo.findOne({
        where: { blocker_id: targetId, blocked_id: userId },
      }),
      this.friendRequestRepo.findOne({
        where: [
          {
            sender_id: userId,
            receiver_id: targetId,
            status: FriendRequestStatus.PENDING,
          },
          {
            sender_id: targetId,
            receiver_id: userId,
            status: FriendRequestStatus.PENDING,
          },
        ],
      }),
    ]);

    return {
      is_friend: !!friendship,
      is_blocked: !!blockedByMe || !!blockedMe,
      has_pending_request: !!pendingRequest,
    };
  }

  async listConversation(userId: string, contactId: string, limit = 100) {
    const take = normalizeLimit(limit, 100);

    const isFriend = await this.friendshipRepo.findOne({
      where: { user_id: userId, friend_id: contactId },
    });
    if (!isFriend) {
      throw new BadRequestException('Contact is not in your friends list');
    }

    const rows = await this.dmRepo
      .createQueryBuilder('m')
      .where(
        '(m.from_user_id = :userId AND m.to_user_id = :contactId) OR (m.from_user_id = :contactId AND m.to_user_id = :userId)',
        { userId, contactId },
      )
      .orderBy('m.created_at', 'DESC')
      .take(take)
      .getMany();

    return rows
      .reverse()
      .map((m) => ({
        id: m.id,
        from_user_id: m.from_user_id,
        to_user_id: m.to_user_id,
        content: m.content,
        created_at: m.created_at,
        read_at: m.read_at,
      }));
  }

  async markConversationRead(userId: string, contactId: string) {
    await this.dmRepo
      .createQueryBuilder()
      .update(DirectMessage)
      .set({ read_at: () => 'NOW()' })
      .where('to_user_id = :userId', { userId })
      .andWhere('from_user_id = :contactId', { contactId })
      .andWhere('read_at IS NULL')
      .execute();

    return { success: true };
  }

  async getUnreadCount(userId: string) {
    const rows = await this.dmRepo
      .createQueryBuilder('m')
      .select('m.from_user_id', 'from_user_id')
      .addSelect('COUNT(*)', 'count')
      .where('m.to_user_id = :userId', { userId })
      .andWhere('m.read_at IS NULL')
      .groupBy('m.from_user_id')
      .getRawMany<{ from_user_id: string; count: string }>();

    const by_user: Record<string, number> = {};
    let total = 0;

    for (const row of rows) {
      const count = parseInt(row.count, 10) || 0;
      by_user[row.from_user_id] = count;
      total += count;
    }

    return { total, by_user };
  }

  private async ensureFriendshipPair(userId: string, friendId: string) {
    const [existingA, existingB] = await Promise.all([
      this.friendshipRepo.findOne({
        where: { user_id: userId, friend_id: friendId },
      }),
      this.friendshipRepo.findOne({
        where: { user_id: friendId, friend_id: userId },
      }),
    ]);

    if (!existingA) {
      await this.friendshipRepo.save(
        this.friendshipRepo.create({
          user_id: userId,
          friend_id: friendId,
        }),
      );
    }

    if (!existingB) {
      await this.friendshipRepo.save(
        this.friendshipRepo.create({
          user_id: friendId,
          friend_id: userId,
        }),
      );
    }
  }

  private mapFriend(friend: User | null | undefined) {
    if (!friend) {
      return null;
    }

    return {
      id: friend.id,
      username: friend.username,
      avatar_url: friend.avatar_url,
      elo: friend.elo,
    };
  }
}
