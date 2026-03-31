import { User } from '../../users/entities/user.entity';
export declare class Notification {
    id: string;
    user_id: string;
    type: string;
    title: string;
    body: string | null;
    data: Record<string, unknown> | null;
    is_read: boolean;
    created_at: Date;
    user: User;
}
