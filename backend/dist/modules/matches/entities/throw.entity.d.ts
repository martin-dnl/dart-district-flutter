import { Leg } from './leg.entity';
import { User } from '../../users/entities/user.entity';
export declare class Throw {
    id: string;
    leg_id: string;
    user_id: string;
    round_num: number;
    dart_num: number;
    segment: string;
    score: number;
    remaining: number;
    dart_positions?: Array<{
        x: number;
        y: number;
        score?: number;
        label?: string;
    }>;
    is_checkout: boolean;
    created_at: Date;
    leg: Leg;
    user: User;
}
