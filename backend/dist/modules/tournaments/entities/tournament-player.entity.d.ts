import { Tournament } from './tournament.entity';
import { User } from '../../users/entities/user.entity';
import { TournamentPool } from './tournament-pool.entity';
export declare class TournamentPlayer {
    id: string;
    tournament_id: string;
    user_id: string;
    seed: number | null;
    pool_id: string | null;
    is_qualified: boolean;
    is_disqualified: boolean;
    disqualification_reason: string | null;
    registered_at: Date;
    tournament: Tournament;
    user: User;
    pool: TournamentPool | null;
}
