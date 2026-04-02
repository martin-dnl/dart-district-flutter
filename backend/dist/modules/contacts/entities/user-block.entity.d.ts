import { User } from '../../users/entities/user.entity';
export declare class UserBlock {
    id: string;
    blocker_id: string;
    blocked_id: string;
    created_at: Date;
    blocker: User;
    blocked: User;
}
