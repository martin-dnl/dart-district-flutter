import { MatchesService } from './matches.service';
import { CreateMatchDto } from './dto/create-match.dto';
import { SubmitThrowDto } from './dto/submit-throw.dto';
export declare class MatchesController {
    private readonly matchesService;
    constructor(matchesService: MatchesService);
    createInvitation(body: {
        invitee_id: string;
        mode: string;
        starting_score?: number;
        player_names?: string[];
        sets_to_win?: number;
        legs_per_set?: number;
        finish_type?: string;
        territory_club_id?: string;
        territory_code_iris?: string;
    }, req: {
        user: {
            id: string;
        };
    }): Promise<{
        id: string;
        mode: string;
        starting_score: number;
        players: {
            user_id: string;
            name: string;
            score: number;
            legs_won: number;
            sets_won: number;
            throw_scores: number[];
            average: number;
            doubles_attempted: number;
            doubles_hit: number;
        }[];
        starting_player_index: number;
        current_player_index: number;
        current_round: number;
        current_leg: number;
        current_set: number;
        status: string;
        round_history: {
            player_index: number;
            round: number;
            darts: number[];
            total: number;
            is_bust: boolean;
            doubles_attempted: number;
            dart_positions: {
                x: number;
                y: number;
                score?: number;
                label?: string;
            }[];
        }[];
        inviter_id: string | null;
        invitee_id: string | null;
        invitation_status: string | null;
        invitation_created_at: Date | null;
        sets_to_win: number;
        legs_per_set: number;
        finish_type: string;
        is_ranked: boolean;
        is_territorial: boolean;
        territory_club_id: string | null;
        territory_code_iris: string | null;
        abandoned_by_index: number | null;
    }>;
    ongoing(req: {
        user: {
            id: string;
        };
    }): Promise<{
        id: string;
        mode: string;
        starting_score: number;
        players: {
            user_id: string;
            name: string;
            score: number;
            legs_won: number;
            sets_won: number;
            throw_scores: number[];
            average: number;
            doubles_attempted: number;
            doubles_hit: number;
        }[];
        starting_player_index: number;
        current_player_index: number;
        current_round: number;
        current_leg: number;
        current_set: number;
        status: string;
        round_history: {
            player_index: number;
            round: number;
            darts: number[];
            total: number;
            is_bust: boolean;
            doubles_attempted: number;
            dart_positions: {
                x: number;
                y: number;
                score?: number;
                label?: string;
            }[];
        }[];
        inviter_id: string | null;
        invitee_id: string | null;
        invitation_status: string | null;
        invitation_created_at: Date | null;
        sets_to_win: number;
        legs_per_set: number;
        finish_type: string;
        is_ranked: boolean;
        is_territorial: boolean;
        territory_club_id: string | null;
        territory_code_iris: string | null;
        abandoned_by_index: number | null;
    }[]>;
    acceptInvitation(id: string, req: {
        user: {
            id: string;
        };
    }): Promise<{
        id: string;
        mode: string;
        starting_score: number;
        players: {
            user_id: string;
            name: string;
            score: number;
            legs_won: number;
            sets_won: number;
            throw_scores: number[];
            average: number;
            doubles_attempted: number;
            doubles_hit: number;
        }[];
        starting_player_index: number;
        current_player_index: number;
        current_round: number;
        current_leg: number;
        current_set: number;
        status: string;
        round_history: {
            player_index: number;
            round: number;
            darts: number[];
            total: number;
            is_bust: boolean;
            doubles_attempted: number;
            dart_positions: {
                x: number;
                y: number;
                score?: number;
                label?: string;
            }[];
        }[];
        inviter_id: string | null;
        invitee_id: string | null;
        invitation_status: string | null;
        invitation_created_at: Date | null;
        sets_to_win: number;
        legs_per_set: number;
        finish_type: string;
        is_ranked: boolean;
        is_territorial: boolean;
        territory_club_id: string | null;
        territory_code_iris: string | null;
        abandoned_by_index: number | null;
    }>;
    refuseInvitation(id: string, req: {
        user: {
            id: string;
        };
    }): Promise<{
        ok: boolean;
    }>;
    cancelInvitation(id: string, req: {
        user: {
            id: string;
        };
    }): Promise<{
        ok: boolean;
    }>;
    submitScore(id: string, body: {
        player_index: number;
        score: number;
        doubles_attempted?: number;
        dart_positions?: Array<{
            x: number;
            y: number;
            score?: number;
            label?: string;
        }>;
    }, req: {
        user: {
            id: string;
        };
    }): Promise<{
        id: string;
        mode: string;
        starting_score: number;
        players: {
            user_id: string;
            name: string;
            score: number;
            legs_won: number;
            sets_won: number;
            throw_scores: number[];
            average: number;
            doubles_attempted: number;
            doubles_hit: number;
        }[];
        starting_player_index: number;
        current_player_index: number;
        current_round: number;
        current_leg: number;
        current_set: number;
        status: string;
        round_history: {
            player_index: number;
            round: number;
            darts: number[];
            total: number;
            is_bust: boolean;
            doubles_attempted: number;
            dart_positions: {
                x: number;
                y: number;
                score?: number;
                label?: string;
            }[];
        }[];
        inviter_id: string | null;
        invitee_id: string | null;
        invitation_status: string | null;
        invitation_created_at: Date | null;
        sets_to_win: number;
        legs_per_set: number;
        finish_type: string;
        is_ranked: boolean;
        is_territorial: boolean;
        territory_club_id: string | null;
        territory_code_iris: string | null;
        abandoned_by_index: number | null;
    }>;
    undoLastThrow(id: string, req: {
        user: {
            id: string;
        };
    }): Promise<{
        id: string;
        mode: string;
        starting_score: number;
        players: {
            user_id: string;
            name: string;
            score: number;
            legs_won: number;
            sets_won: number;
            throw_scores: number[];
            average: number;
            doubles_attempted: number;
            doubles_hit: number;
        }[];
        starting_player_index: number;
        current_player_index: number;
        current_round: number;
        current_leg: number;
        current_set: number;
        status: string;
        round_history: {
            player_index: number;
            round: number;
            darts: number[];
            total: number;
            is_bust: boolean;
            doubles_attempted: number;
            dart_positions: {
                x: number;
                y: number;
                score?: number;
                label?: string;
            }[];
        }[];
        inviter_id: string | null;
        invitee_id: string | null;
        invitation_status: string | null;
        invitation_created_at: Date | null;
        sets_to_win: number;
        legs_per_set: number;
        finish_type: string;
        is_ranked: boolean;
        is_territorial: boolean;
        territory_club_id: string | null;
        territory_code_iris: string | null;
        abandoned_by_index: number | null;
    }>;
    abandonMatch(id: string, body: {
        surrendered_by_index: number;
    }, req: {
        user: {
            id: string;
        };
    }): Promise<{
        id: string;
        mode: string;
        starting_score: number;
        players: {
            user_id: string;
            name: string;
            score: number;
            legs_won: number;
            sets_won: number;
            throw_scores: number[];
            average: number;
            doubles_attempted: number;
            doubles_hit: number;
        }[];
        starting_player_index: number;
        current_player_index: number;
        current_round: number;
        current_leg: number;
        current_set: number;
        status: string;
        round_history: {
            player_index: number;
            round: number;
            darts: number[];
            total: number;
            is_bust: boolean;
            doubles_attempted: number;
            dart_positions: {
                x: number;
                y: number;
                score?: number;
                label?: string;
            }[];
        }[];
        inviter_id: string | null;
        invitee_id: string | null;
        invitation_status: string | null;
        invitation_created_at: Date | null;
        sets_to_win: number;
        legs_per_set: number;
        finish_type: string;
        is_ranked: boolean;
        is_territorial: boolean;
        territory_club_id: string | null;
        territory_code_iris: string | null;
        abandoned_by_index: number | null;
    }>;
    create(dto: CreateMatchDto): Promise<import("./entities/match.entity").Match>;
    myMatches(req: {
        user: {
            id: string;
        };
    }, limit?: number, offset?: number, status?: string, ranked?: string): Promise<{
        id: string;
        mode: string;
        status: string;
        is_ranked: boolean;
        created_at: Date;
        started_at: Date | null;
        completed_at: Date | null;
        surrendered_by: string | null;
        winner_id: string | null;
        players: {
            user_id: string;
            username: string;
            avatar_url: string | null;
            is_winner: boolean | null;
            sets_won: number;
        }[];
    }[]>;
    userMatches(userId: string, limit?: number, offset?: number, status?: string, ranked?: string): Promise<{
        id: string;
        mode: string;
        status: string;
        is_ranked: boolean;
        created_at: Date;
        started_at: Date | null;
        completed_at: Date | null;
        surrendered_by: string | null;
        winner_id: string | null;
        players: {
            user_id: string;
            username: string;
            avatar_url: string | null;
            is_winner: boolean | null;
            sets_won: number;
        }[];
    }[]>;
    report(id: string): Promise<{
        match_id: string;
        mode: string;
        final_sets: number[];
        players: {
            user_id: string;
            username: string;
            avatar_url: string | null;
            avg_score: number;
            legs_won: number;
            count_180: number;
            count_140_plus: number;
            count_100_plus: number;
            checkout_rate: number;
            checkout_attempts: number;
            checkout_hits: number;
            highest_checkout: number;
            total_darts: number;
            dart_positions: {
                x: number;
                y: number;
                score: number | undefined;
                label: string | undefined;
            }[];
        }[];
        timeline: {
            set: number;
            leg: number;
            winner_username: string;
        }[];
    }>;
    resultSummary(id: string, req: {
        user: {
            id: string;
        };
    }): Promise<{
        match_id: string;
        is_ranked: boolean;
        is_territorial: boolean;
        user_id: string;
        is_winner: boolean;
        elo_before: number;
        elo_after: number;
        elo_delta: number;
        territory_points_gained: number;
        territory_code_iris: string | null;
        territory_name: string | null;
    }>;
    findOne(id: string): Promise<import("./entities/match.entity").Match>;
    submitThrow(matchId: string, legId: string, dto: SubmitThrowDto, req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/throw.entity").Throw>;
    validate(id: string, req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/match.entity").Match>;
}
