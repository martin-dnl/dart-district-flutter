"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ContactsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const friendship_entity_1 = require("./entities/friendship.entity");
const user_entity_1 = require("../users/entities/user.entity");
const direct_message_entity_1 = require("../realtime/entities/direct-message.entity");
const friend_request_entity_1 = require("./entities/friend-request.entity");
const user_block_entity_1 = require("./entities/user-block.entity");
const normalize_limit_1 = require("../../common/utils/normalize-limit");
let ContactsService = class ContactsService {
    constructor(friendshipRepo, friendRequestRepo, userBlockRepo, userRepo, dmRepo) {
        this.friendshipRepo = friendshipRepo;
        this.friendRequestRepo = friendRequestRepo;
        this.userBlockRepo = userBlockRepo;
        this.userRepo = userRepo;
        this.dmRepo = dmRepo;
    }
    async listIncomingRequests(userId) {
        const rows = await this.friendRequestRepo.find({
            where: {
                receiver_id: userId,
                status: friend_request_entity_1.FriendRequestStatus.PENDING,
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
    async listOutgoingRequests(userId) {
        const rows = await this.friendRequestRepo.find({
            where: {
                sender_id: userId,
                status: friend_request_entity_1.FriendRequestStatus.PENDING,
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
    async sendFriendRequest(userId, receiverId) {
        const blockedBetweenUsers = await this.userBlockRepo.findOne({
            where: [
                { blocker_id: userId, blocked_id: receiverId },
                { blocker_id: receiverId, blocked_id: userId },
            ],
        });
        if (blockedBetweenUsers) {
            throw new common_1.ForbiddenException('Friend request unavailable for this user');
        }
        if (userId === receiverId) {
            throw new common_1.BadRequestException('You cannot send a friend request to yourself');
        }
        const receiver = await this.userRepo.findOne({ where: { id: receiverId } });
        if (!receiver) {
            throw new common_1.NotFoundException('Receiver user not found');
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
                status: friend_request_entity_1.FriendRequestStatus.PENDING,
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
                status: friend_request_entity_1.FriendRequestStatus.PENDING,
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
        const created = await this.friendRequestRepo.save(this.friendRequestRepo.create({
            sender_id: userId,
            receiver_id: receiverId,
            status: friend_request_entity_1.FriendRequestStatus.PENDING,
        }));
        return {
            status: 'pending',
            request_id: created.id,
        };
    }
    async acceptFriendRequest(userId, requestId) {
        const request = await this.friendRequestRepo.findOne({
            where: { id: requestId },
            relations: ['sender', 'receiver'],
        });
        if (!request) {
            throw new common_1.NotFoundException('Friend request not found');
        }
        if (request.receiver_id !== userId) {
            throw new common_1.ForbiddenException('You cannot accept this friend request');
        }
        if (request.status !== friend_request_entity_1.FriendRequestStatus.PENDING) {
            return {
                status: request.status,
                friend: this.mapFriend(request.sender),
            };
        }
        request.status = friend_request_entity_1.FriendRequestStatus.ACCEPTED;
        request.responded_at = new Date();
        await this.friendRequestRepo.save(request);
        await this.ensureFriendshipPair(request.sender_id, request.receiver_id);
        return {
            status: 'accepted',
            friend: this.mapFriend(request.sender),
        };
    }
    async rejectFriendRequest(userId, requestId) {
        const request = await this.friendRequestRepo.findOne({
            where: { id: requestId },
            relations: ['sender'],
        });
        if (!request) {
            throw new common_1.NotFoundException('Friend request not found');
        }
        if (request.receiver_id !== userId) {
            throw new common_1.ForbiddenException('You cannot reject this friend request');
        }
        if (request.status !== friend_request_entity_1.FriendRequestStatus.PENDING) {
            return { status: request.status };
        }
        request.status = friend_request_entity_1.FriendRequestStatus.REJECTED;
        request.responded_at = new Date();
        await this.friendRequestRepo.save(request);
        return { status: 'rejected' };
    }
    async listFriends(userId) {
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
    async addFriend(userId, friendId) {
        if (userId === friendId) {
            throw new common_1.BadRequestException('You cannot add yourself as a friend');
        }
        const friend = await this.userRepo.findOne({ where: { id: friendId } });
        if (!friend) {
            throw new common_1.NotFoundException('Friend user not found');
        }
        await this.ensureFriendshipPair(userId, friendId);
        return {
            id: friend.id,
            username: friend.username,
            avatar_url: friend.avatar_url,
            elo: friend.elo,
        };
    }
    async removeFriend(userId, friendId) {
        await this.friendshipRepo.delete([
            { user_id: userId, friend_id: friendId },
            { user_id: friendId, friend_id: userId },
        ]);
        return { success: true };
    }
    async blockUser(blockerId, blockedId) {
        if (blockerId === blockedId) {
            throw new common_1.BadRequestException('You cannot block yourself');
        }
        const target = await this.userRepo.findOne({ where: { id: blockedId } });
        if (!target) {
            throw new common_1.NotFoundException('User not found');
        }
        await this.friendshipRepo.delete([
            { user_id: blockerId, friend_id: blockedId },
            { user_id: blockedId, friend_id: blockerId },
        ]);
        await this.friendRequestRepo
            .createQueryBuilder()
            .update(friend_request_entity_1.FriendRequest)
            .set({ status: friend_request_entity_1.FriendRequestStatus.REJECTED, responded_at: () => 'NOW()' })
            .where('status = :status AND ((sender_id = :blockerId AND receiver_id = :blockedId) OR (sender_id = :blockedId AND receiver_id = :blockerId))', {
            status: friend_request_entity_1.FriendRequestStatus.PENDING,
            blockerId,
            blockedId,
        })
            .execute();
        const existing = await this.userBlockRepo.findOne({
            where: { blocker_id: blockerId, blocked_id: blockedId },
        });
        if (!existing) {
            await this.userBlockRepo.save(this.userBlockRepo.create({ blocker_id: blockerId, blocked_id: blockedId }));
        }
        return { success: true };
    }
    async unblockUser(blockerId, blockedId) {
        await this.userBlockRepo.delete({ blocker_id: blockerId, blocked_id: blockedId });
        return { success: true };
    }
    async getFriendshipStatus(userId, targetId) {
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
                        status: friend_request_entity_1.FriendRequestStatus.PENDING,
                    },
                    {
                        sender_id: targetId,
                        receiver_id: userId,
                        status: friend_request_entity_1.FriendRequestStatus.PENDING,
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
    async listConversation(userId, contactId, limit = 100) {
        const take = (0, normalize_limit_1.normalizeLimit)(limit, 100);
        const isFriend = await this.friendshipRepo.findOne({
            where: { user_id: userId, friend_id: contactId },
        });
        if (!isFriend) {
            throw new common_1.BadRequestException('Contact is not in your friends list');
        }
        const rows = await this.dmRepo
            .createQueryBuilder('m')
            .where('(m.from_user_id = :userId AND m.to_user_id = :contactId) OR (m.from_user_id = :contactId AND m.to_user_id = :userId)', { userId, contactId })
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
    async markConversationRead(userId, contactId) {
        await this.dmRepo
            .createQueryBuilder()
            .update(direct_message_entity_1.DirectMessage)
            .set({ read_at: () => 'NOW()' })
            .where('to_user_id = :userId', { userId })
            .andWhere('from_user_id = :contactId', { contactId })
            .andWhere('read_at IS NULL')
            .execute();
        return { success: true };
    }
    async getUnreadCount(userId) {
        const rows = await this.dmRepo
            .createQueryBuilder('m')
            .select('m.from_user_id', 'from_user_id')
            .addSelect('COUNT(*)', 'count')
            .where('m.to_user_id = :userId', { userId })
            .andWhere('m.read_at IS NULL')
            .groupBy('m.from_user_id')
            .getRawMany();
        const by_user = {};
        let total = 0;
        for (const row of rows) {
            const count = parseInt(row.count, 10) || 0;
            by_user[row.from_user_id] = count;
            total += count;
        }
        return { total, by_user };
    }
    async ensureFriendshipPair(userId, friendId) {
        const [existingA, existingB] = await Promise.all([
            this.friendshipRepo.findOne({
                where: { user_id: userId, friend_id: friendId },
            }),
            this.friendshipRepo.findOne({
                where: { user_id: friendId, friend_id: userId },
            }),
        ]);
        if (!existingA) {
            await this.friendshipRepo.save(this.friendshipRepo.create({
                user_id: userId,
                friend_id: friendId,
            }));
        }
        if (!existingB) {
            await this.friendshipRepo.save(this.friendshipRepo.create({
                user_id: friendId,
                friend_id: userId,
            }));
        }
    }
    mapFriend(friend) {
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
};
exports.ContactsService = ContactsService;
exports.ContactsService = ContactsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(friendship_entity_1.Friendship)),
    __param(1, (0, typeorm_1.InjectRepository)(friend_request_entity_1.FriendRequest)),
    __param(2, (0, typeorm_1.InjectRepository)(user_block_entity_1.UserBlock)),
    __param(3, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __param(4, (0, typeorm_1.InjectRepository)(direct_message_entity_1.DirectMessage)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], ContactsService);
//# sourceMappingURL=contacts.service.js.map