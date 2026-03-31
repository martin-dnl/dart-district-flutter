import { User } from '../../users/entities/user.entity';
export declare class DirectMessage {
    id: string;
    from_user_id: string;
    to_user_id: string;
    content: string;
    created_at: Date;
    read_at: Date | null;
    from_user: User;
    to_user: User;
}
