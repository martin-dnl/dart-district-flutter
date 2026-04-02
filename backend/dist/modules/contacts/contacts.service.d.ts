import { Repository } from 'typeorm';
import { Friendship } from './entities/friendship.entity';
import { User } from '../users/entities/user.entity';
import { DirectMessage } from '../realtime/entities/direct-message.entity';
import { FriendRequest } from './entities/friend-request.entity';
import { UserBlock } from './entities/user-block.entity';
export declare class ContactsService {
    private readonly friendshipRepo;
    private readonly friendRequestRepo;
    private readonly userBlockRepo;
    private readonly userRepo;
    private readonly dmRepo;
    constructor(friendshipRepo: Repository<Friendship>, friendRequestRepo: Repository<FriendRequest>, userBlockRepo: Repository<UserBlock>, userRepo: Repository<User>, dmRepo: Repository<DirectMessage>);
    listIncomingRequests(userId: string): Promise<{
        id: string;
        created_at: Date;
        sender: {
            id: string;
            username: string;
            avatar_url: string | null;
            elo: number;
        } | null;
    }[]>;
    listOutgoingRequests(userId: string): Promise<{
        id: string;
        created_at: Date;
        receiver: {
            id: string;
            username: string;
            avatar_url: string | null;
            elo: number;
        } | null;
    }[]>;
    sendFriendRequest(userId: string, receiverId: string): Promise<{
        status: string;
        friend: {
            id: string;
            username: string;
            avatar_url: string | null;
            elo: number;
        } | null;
        request_id?: undefined;
    } | {
        status: string;
        request_id: string;
        friend?: undefined;
    }>;
    acceptFriendRequest(userId: string, requestId: string): Promise<{
        status: string;
        friend: {
            id: string;
            username: string;
            avatar_url: string | null;
            elo: number;
        } | null;
    }>;
    rejectFriendRequest(userId: string, requestId: string): Promise<{
        status: string;
    }>;
    listFriends(userId: string): Promise<{
        id: string;
        username: string;
        avatar_url: string | null;
        elo: number;
    }[]>;
    addFriend(userId: string, friendId: string): Promise<{
        id: string;
        username: string;
        avatar_url: string | null;
        elo: number;
    }>;
    removeFriend(userId: string, friendId: string): Promise<{
        success: boolean;
    }>;
    blockUser(blockerId: string, blockedId: string): Promise<{
        success: boolean;
    }>;
    unblockUser(blockerId: string, blockedId: string): Promise<{
        success: boolean;
    }>;
    getFriendshipStatus(userId: string, targetId: string): Promise<{
        is_friend: boolean;
        is_blocked: boolean;
        has_pending_request: boolean;
    }>;
    listConversation(userId: string, contactId: string, limit?: number): Promise<{
        id: string;
        from_user_id: string;
        to_user_id: string;
        content: string;
        created_at: Date;
        read_at: Date | null;
    }[]>;
    markConversationRead(userId: string, contactId: string): Promise<{
        success: boolean;
    }>;
    getUnreadCount(userId: string): Promise<{
        total: number;
        by_user: Record<string, number>;
    }>;
    private ensureFriendshipPair;
    private mapFriend;
}
