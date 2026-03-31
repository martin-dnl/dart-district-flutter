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
    is_checkout: boolean;
    created_at: Date;
    leg: Leg;
    user: User;
}
