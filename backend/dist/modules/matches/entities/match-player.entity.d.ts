import { Match } from './match.entity';
import { User } from '../../users/entities/user.entity';
import { Club } from '../../clubs/entities/club.entity';
export declare class MatchPlayer {
    id: string;
    match_id: string;
    user_id: string;
    club_id: string | null;
    side: string;
    final_score: number | null;
    avg_score: number | null;
    is_winner: boolean | null;
    match: Match;
    user: User;
    club: Club;
}
