import { TournamentsService } from './tournaments.service';
import { CreateTournamentDto } from './dto/create-tournament.dto';
import { DisqualifyPlayerDto } from './dto/disqualify-player.dto';
export declare class TournamentsController {
    private readonly tournamentsService;
    constructor(tournamentsService: TournamentsService);
    create(dto: CreateTournamentDto, req: {
        user: {
            id: string;
            is_guest?: boolean;
            is_admin?: boolean;
        };
    }): Promise<import("./entities/tournament.entity").Tournament>;
    findAll(status?: string, upcoming?: string, clubId?: string): Promise<import("./entities/tournament.entity").Tournament[]>;
    findOne(id: string): Promise<{
        players: import("./entities/tournament-player.entity").TournamentPlayer[];
        id: string;
        name: string;
        description: string | null;
        territory_id: string | null;
        is_territorial: boolean;
        is_ranked: boolean;
        mode: string;
        finish: string;
        venue_name: string | null;
        venue_address: string | null;
        city: string | null;
        club_id: string | null;
        entry_fee: number;
        max_players: number;
        enrolled_players: number;
        format: string;
        pool_count: number | null;
        players_per_pool: number | null;
        qualified_per_pool: number;
        legs_per_set_pool: number;
        sets_to_win_pool: number;
        legs_per_set_bracket: number;
        sets_to_win_bracket: number;
        current_phase: string;
        status: string;
        scheduled_at: Date;
        ended_at: Date | null;
        created_by: string | null;
        created_at: Date;
        territory: import("../territories/entities/territory.entity").Territory;
        creator: import("../users/entities/user.entity").User;
        club: import("../clubs/entities/club.entity").Club;
        pools: import("./entities/tournament-pool.entity").TournamentPool[];
        bracket_matches: import("./entities/tournament-bracket-match.entity").TournamentBracketMatch[];
    }>;
    register(id: string, req: {
        user: {
            id: string;
            is_guest?: boolean;
        };
    }): Promise<import("./entities/tournament-player.entity").TournamentPlayer>;
    unregister(id: string, req: {
        user: {
            id: string;
        };
    }): Promise<void>;
    generatePools(id: string, req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/tournament-pool.entity").TournamentPool[]>;
    getPools(id: string): Promise<import("./entities/tournament-pool.entity").TournamentPool[]>;
    getPoolStandings(poolId: string): Promise<import("./entities/tournament-pool-standing.entity").TournamentPoolStanding[]>;
    generateBracket(id: string, req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/tournament-bracket-match.entity").TournamentBracketMatch[]>;
    getBracket(id: string): Promise<import("./entities/tournament-bracket-match.entity").TournamentBracketMatch[]>;
    advancePhase(id: string, req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/tournament.entity").Tournament>;
    disqualify(id: string, playerId: string, dto: DisqualifyPlayerDto, req: {
        user: {
            id: string;
        };
    }): Promise<void>;
}
