import { DataSource, Repository } from 'typeorm';
import { Club } from './entities/club.entity';
import { ClubMember } from './entities/club-member.entity';
import { CreateClubDto } from './dto/create-club.dto';
import { UpdateClubDto } from './dto/update-club.dto';
export declare class ClubsService {
    private readonly clubRepo;
    private readonly memberRepo;
    private readonly dataSource;
    constructor(clubRepo: Repository<Club>, memberRepo: Repository<ClubMember>, dataSource: DataSource);
    create(dto: CreateClubDto, userId: string): Promise<Club>;
    findAll(limit?: number, q?: string, city?: string): Promise<Club[]>;
    search(params: {
        q?: string;
        lat?: number;
        lng?: number;
        radius?: number;
        limit?: number;
    }): Promise<Club[]>;
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
        city: string | null;
    }[]>;
    private resolveNearestCodeIris;
    private assertRole;
}
