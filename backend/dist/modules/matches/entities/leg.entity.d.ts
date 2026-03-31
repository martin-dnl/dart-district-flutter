import { Set } from './set.entity';
import { User } from '../../users/entities/user.entity';
import { Throw } from './throw.entity';
export declare class Leg {
    id: string;
    set_id: string;
    leg_number: number;
    winner_id: string | null;
    starting_score: number;
    created_at: Date;
    set: Set;
    winner: User;
    throws: Throw[];
}
