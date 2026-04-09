export declare class CreateMatchDto {
    mode: '501' | '301' | 'cricket';
    finish_type: 'double_out' | 'straight_out' | 'master_out';
    best_of_sets: number;
    best_of_legs: number;
    player_ids: string[];
    is_territorial?: boolean;
    is_ranked?: boolean;
    territory_id?: string;
    club_id?: string;
    tournament_id?: string;
}
