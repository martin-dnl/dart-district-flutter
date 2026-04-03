import { User } from './user.entity';
export declare class UserSetting {
    id: string;
    user_id: string;
    user: User;
    key: string;
    value: string;
    created_at: Date;
    updated_at: Date;
}
