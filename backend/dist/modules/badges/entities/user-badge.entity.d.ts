import { User } from '../../users/entities/user.entity';
import { Badge } from './badge.entity';
export declare class UserBadge {
    id: string;
    user_id: string;
    badge_id: string;
    earned_at: Date;
    user: User;
    badge: Badge;
}
