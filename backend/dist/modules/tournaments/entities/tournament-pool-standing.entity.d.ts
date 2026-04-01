import { TournamentPool } from './tournament-pool.entity';
import { User } from '../../users/entities/user.entity';
export declare class TournamentPoolStanding {
    id: string;
    pool_id: string;
    user_id: string;
    matches_played: number;
    matches_won: number;
    legs_won: number;
    legs_lost: number;
    points: number;
    rank: number | null;
    pool: TournamentPool;
    user: User;
}
