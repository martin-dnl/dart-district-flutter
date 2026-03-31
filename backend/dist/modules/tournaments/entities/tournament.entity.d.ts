import { Territory } from '../../territories/entities/territory.entity';
import { User } from '../../users/entities/user.entity';
export declare class Tournament {
    id: string;
    name: string;
    description: string | null;
    territory_id: string | null;
    is_territorial: boolean;
    mode: string;
    finish: string;
    venue_name: string | null;
    venue_address: string | null;
    city: string | null;
    entry_fee: number;
    max_clubs: number;
    enrolled_clubs: number;
    status: string;
    scheduled_at: Date;
    ended_at: Date | null;
    created_by: string | null;
    created_at: Date;
    territory: Territory;
    creator: User;
}
