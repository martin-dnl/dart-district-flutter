import { User } from '../../users/entities/user.entity';
export declare class AuthProvider {
    id: string;
    user_id: string;
    provider: string;
    provider_uid: string;
    access_token: string | null;
    refresh_token: string | null;
    created_at: Date;
    user: User;
}
