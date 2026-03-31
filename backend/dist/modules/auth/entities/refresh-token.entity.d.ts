import { User } from '../../users/entities/user.entity';
export declare class RefreshToken {
    id: string;
    user_id: string;
    token: string;
    expires_at: Date;
    revoked: boolean;
    created_at: Date;
    user: User;
}
