import { Tournament } from './tournament.entity';
import { TournamentPlayer } from './tournament-player.entity';
import { TournamentPoolStanding } from './tournament-pool-standing.entity';
export declare class TournamentPool {
    id: string;
    tournament_id: string;
    pool_name: string;
    created_at: Date;
    tournament: Tournament;
    players: TournamentPlayer[];
    standings: TournamentPoolStanding[];
}
