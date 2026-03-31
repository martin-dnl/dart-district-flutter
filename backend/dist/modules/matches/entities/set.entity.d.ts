import { Match } from './match.entity';
import { User } from '../../users/entities/user.entity';
import { Leg } from './leg.entity';
export declare class Set {
    id: string;
    match_id: string;
    set_number: number;
    winner_id: string | null;
    created_at: Date;
    match: Match;
    winner: User;
    legs: Leg[];
}
