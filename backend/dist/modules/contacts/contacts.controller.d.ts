import { ContactsService } from './contacts.service';
import { AddFriendDto } from './dto/add-friend.dto';
import { SendFriendRequestDto } from './dto/send-friend-request.dto';
export declare class ContactsController {
    private readonly contactsService;
    constructor(contactsService: ContactsService);
    incomingRequests(req: {
        user: {
            id: string;
        };
    }): Promise<{
        id: string;
        created_at: Date;
        sender: {
            id: string;
            username: string;
            avatar_url: string | null;
            elo: number;
        } | null;
    }[]>;
    outgoingRequests(req: {
        user: {
            id: string;
        };
    }): Promise<{
        id: string;
        created_at: Date;
        receiver: {
            id: string;
            username: string;
            avatar_url: string | null;
            elo: number;
        } | null;
    }[]>;
    sendRequest(req: {
        user: {
            id: string;
        };
    }, dto: SendFriendRequestDto): Promise<{
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
    acceptRequest(req: {
        user: {
            id: string;
        };
    }, requestId: string): Promise<{
        status: string;
        friend: {
            id: string;
            username: string;
            avatar_url: string | null;
            elo: number;
        } | null;
    }>;
    rejectRequest(req: {
        user: {
            id: string;
        };
    }, requestId: string): Promise<{
        status: string;
    }>;
    listFriends(req: {
        user: {
            id: string;
        };
    }): Promise<{
        id: string;
        username: string;
        avatar_url: string | null;
        elo: number;
    }[]>;
    addFriend(req: {
        user: {
            id: string;
        };
    }, dto: AddFriendDto): Promise<{
        id: string;
        username: string;
        avatar_url: string | null;
        elo: number;
    }>;
    removeFriend(req: {
        user: {
            id: string;
        };
    }, friendId: string): Promise<{
        success: boolean;
    }>;
    blockUser(req: {
        user: {
            id: string;
        };
    }, userId: string): Promise<{
        success: boolean;
    }>;
    unblockUser(req: {
        user: {
            id: string;
        };
    }, userId: string): Promise<{
        success: boolean;
    }>;
    status(req: {
        user: {
            id: string;
        };
    }, userId: string): Promise<{
        is_friend: boolean;
        is_blocked: boolean;
        has_pending_request: boolean;
    }>;
    listConversation(req: {
        user: {
            id: string;
        };
    }, contactId: string, limit?: number): Promise<{
        id: string;
        from_user_id: string;
        to_user_id: string;
        content: string;
        created_at: Date;
        read_at: Date | null;
    }[]>;
    markRead(req: {
        user: {
            id: string;
        };
    }, contactId: string): Promise<{
        success: boolean;
    }>;
    unread(req: {
        user: {
            id: string;
        };
    }): Promise<{
        total: number;
        by_user: Record<string, number>;
    }>;
}
