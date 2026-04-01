import { UserBadge } from './user-badge.entity';
export declare class Badge {
    id: string;
    key: string;
    name: string;
    description: string | null;
    image_asset: string;
    category: string;
    created_at: Date;
    user_badges: UserBadge[];
}
