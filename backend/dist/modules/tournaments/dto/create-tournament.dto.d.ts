export declare class CreateTournamentDto {
    name: string;
    territory_id?: string;
    venue_name?: string;
    venue_address?: string;
    city?: string;
    is_territorial?: boolean;
    mode?: string;
    finish?: string;
    entry_fee?: number;
    max_players: number;
    format?: string;
    pool_count?: number;
    qualified_per_pool?: number;
    legs_per_set_pool?: number;
    sets_to_win_pool?: number;
    legs_per_set_bracket?: number;
    sets_to_win_bracket?: number;
    scheduled_at: string;
}
