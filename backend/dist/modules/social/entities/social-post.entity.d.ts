import { User } from '../../users/entities/user.entity';
export declare class SocialPost {
    id: string;
    author_id: string;
    match_id: string;
    mode: string;
    sets_score: string;
    result_label: string;
    description: string | null;
    player_1_name: string | null;
    player_1_score: number | null;
    player_2_name: string | null;
    player_2_score: number | null;
    winner_user_id: string | null;
    match_average: number | null;
    match_checkout_rate: number | null;
    created_at: Date;
    author: User;
}
