import { User } from '../../users/entities/user.entity';
export declare class Friendship {
    id: string;
    user_id: string;
    friend_id: string;
    created_at: Date;
    user: User;
    friend: User;
}
