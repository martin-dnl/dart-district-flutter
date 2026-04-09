import { ClubsService } from './clubs.service';
import { CreateClubDto } from './dto/create-club.dto';
import { UpdateClubDto } from './dto/update-club.dto';
import { ManageMemberDto } from './dto/manage-member.dto';
import { ResolveTerritoryDto } from './dto/resolve-territory.dto';
import { TerritoriesService } from '../territories/territories.service';
export declare class ClubsController {
    private readonly clubsService;
    private readonly territoriesService;
    private readonly logger;
    constructor(clubsService: ClubsService, territoriesService: TerritoriesService);
    resolveTerritory(dto: ResolveTerritoryDto): Promise<{
        success: boolean;
        data: null;
        error: string;
    } | {
        success: boolean;
        data: {
            code_iris: string;
            name: string;
            city: string | null;
            department: string | null;
            region: string | null;
            latitude: number;
            longitude: number;
        };
        error: null;
    }>;
    create(dto: CreateClubDto, req: {
        user: {
            id: string;
            is_guest?: boolean;
        };
    }): Promise<import("./entities/club.entity").Club | null>;
    findAll(limit?: number, q?: string, city?: string): Promise<import("./entities/club.entity").Club[]>;
    search(q?: string, lat?: number, lng?: number, radius?: number, limit?: number): Promise<import("./entities/club.entity").Club[]>;
    ranking(limit?: number): Promise<import("./entities/club.entity").Club[]>;
    mapClubs(): Promise<{
        id: string;
        name: string;
        latitude: number;
        longitude: number;
        code_iris: string | null;
        address: string | null;
        city: string | null;
    }[]>;
    findOne(id: string): Promise<import("./entities/club.entity").Club>;
    territoryPointsTotal(id: string): Promise<{
        club_id: string;
        points: number;
    }>;
    update(id: string, dto: UpdateClubDto, req: {
        user: {
            id: string;
            is_guest?: boolean;
        };
    }): Promise<import("./entities/club.entity").Club>;
    addMember(id: string, dto: ManageMemberDto, req: {
        user: {
            id: string;
            is_guest?: boolean;
        };
    }): Promise<import("./entities/club-member.entity").ClubMember>;
    updateRole(id: string, userId: string, dto: ManageMemberDto, req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/club-member.entity").ClubMember>;
    removeMember(id: string, userId: string, req: {
        user: {
            id: string;
        };
    }): Promise<void>;
}
