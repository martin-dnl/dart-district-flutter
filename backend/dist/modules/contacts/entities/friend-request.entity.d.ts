import { User } from '../../users/entities/user.entity';
export declare enum FriendRequestStatus {
    PENDING = "pending",
    ACCEPTED = "accepted",
    REJECTED = "rejected",
    CANCELED = "canceled"
}
export declare class FriendRequest {
    id: string;
    sender_id: string;
    receiver_id: string;
    status: FriendRequestStatus;
    created_at: Date;
    responded_at: Date | null;
    sender: User;
    receiver: User;
}
