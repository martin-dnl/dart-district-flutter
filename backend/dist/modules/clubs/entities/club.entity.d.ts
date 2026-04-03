import { ClubMember } from './club-member.entity';
export declare class Club {
    id: string;
    name: string;
    description: string | null;
    avatar_url: string | null;
    address: string | null;
    city: string | null;
    region: string | null;
    latitude: number | null;
    longitude: number | null;
    code_iris: string | null;
    conquest_points: number;
    dart_boards_count: number;
    rank: number | null;
    status: string;
    created_at: Date;
    updated_at: Date;
    members: ClubMember[];
}
