import { User } from '../../users/entities/user.entity';
export declare class EloHistory {
    id: string;
    user_id: string;
    match_id: string | null;
    elo_before: number;
    elo_after: number;
    delta: number;
    created_at: Date;
    user: User;
}
