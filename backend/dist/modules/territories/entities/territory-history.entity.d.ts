import { Territory } from './territory.entity';
import { Club } from '../../clubs/entities/club.entity';
export declare class TerritoryHistory {
    id: string;
    territory_id: string;
    from_club_id: string | null;
    to_club_id: string | null;
    match_id: string | null;
    event: string;
    created_at: Date;
    territory: Territory;
    from_club: Club;
    to_club: Club;
}
