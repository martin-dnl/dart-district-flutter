import { User } from '../../users/entities/user.entity';
export declare class PlayerStat {
    id: string;
    user_id: string;
    matches_played: number;
    matches_won: number;
    avg_score: number;
    best_avg: number;
    checkout_rate: number;
    total_180s: number;
    count_140_plus: number;
    count_100_plus: number;
    high_finish: number;
    best_leg_darts: number;
    precision_t20: number;
    precision_t19: number;
    precision_double: number;
    updated_at: Date;
    user: User;
}
