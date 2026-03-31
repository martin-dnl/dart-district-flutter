import { Club } from './club.entity';
import { User } from '../../users/entities/user.entity';
export declare class ClubMember {
    id: string;
    club_id: string;
    user_id: string;
    role: string;
    joined_at: Date;
    is_active: boolean;
    club: Club;
    user: User;
}
