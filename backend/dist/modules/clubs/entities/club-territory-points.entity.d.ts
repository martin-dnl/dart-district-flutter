import { Club } from './club.entity';
export declare class ClubTerritoryPoints {
    id: string;
    club_id: string;
    code_iris: string;
    points: number;
    created_at: Date;
    updated_at: Date;
    club: Club;
}
