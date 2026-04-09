import { DataSource, Repository } from 'typeorm';
import { Club } from './entities/club.entity';
import { ClubMember } from './entities/club-member.entity';
import { ClubTerritoryPoints } from './entities/club-territory-points.entity';
import { CreateClubDto } from './dto/create-club.dto';
import { UpdateClubDto } from './dto/update-club.dto';
export declare class ClubsService {
    private readonly clubRepo;
    private readonly memberRepo;
    private readonly ctpRepo;
    private readonly dataSource;
    private readonly logger;
    constructor(clubRepo: Repository<Club>, memberRepo: Repository<ClubMember>, ctpRepo: Repository<ClubTerritoryPoints>, dataSource: DataSource);
    create(dto: CreateClubDto, _userId: string): Promise<Club | null>;
    findAll(limit?: number, q?: string, city?: string): Promise<Club[]>;
    search(params: {
        q?: string;
        lat?: number;
        lng?: number;
        radius?: number;
        limit?: number;
    }): Promise<Club[]>;
    getMembership(clubId: string, userId: string): Promise<ClubMember | null>;
    getTerritoryTopClubs(codeIris: string, limit?: number): Promise<ClubTerritoryPoints[]>;
    getTerritoryPointsTotal(clubId: string): Promise<{
        club_id: string;
        points: number;
    }>;
    findById(id: string): Promise<Club>;
    update(id: string, dto: UpdateClubDto, userId: string): Promise<Club>;
    addMember(clubId: string, userId: string, role?: 'president' | 'captain' | 'player'): Promise<ClubMember>;
    removeMember(clubId: string, targetUserId: string, requesterId: string): Promise<void>;
    updateMemberRole(clubId: string, targetUserId: string, role: string, requesterId: string): Promise<ClubMember>;
    ranking(limit?: number): Promise<Club[]>;
    findForMap(): Promise<{
        id: string;
        name: string;
        latitude: number;
        longitude: number;
        code_iris: string | null;
        address: string | null;
        city: string | null;
    }[]>;
    resolveNearestCodeIris(latitude: number, longitude: number, maxDistanceKm?: number): Promise<string | null>;
    private haversineDistanceKm;
    private assertRole;
}
