import { Tournament } from './tournament.entity';
import { User } from '../../users/entities/user.entity';
export declare class TournamentBracketMatch {
    id: string;
    tournament_id: string;
    round_number: number;
    position: number;
    player1_id: string | null;
    player2_id: string | null;
    winner_id: string | null;
    match_id: string | null;
    status: string;
    scheduled_at: Date | null;
    tournament: Tournament;
    player1: User | null;
    player2: User | null;
    winner: User | null;
}
