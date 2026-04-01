import { ClubsService } from './clubs.service';
import { CreateClubDto } from './dto/create-club.dto';
import { UpdateClubDto } from './dto/update-club.dto';
import { ManageMemberDto } from './dto/manage-member.dto';
export declare class ClubsController {
    private readonly clubsService;
    constructor(clubsService: ClubsService);
    create(dto: CreateClubDto, req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/club.entity").Club>;
    findAll(limit?: number, q?: string, city?: string): Promise<import("./entities/club.entity").Club[]>;
    search(q?: string, lat?: number, lng?: number, radius?: number, limit?: number): Promise<import("./entities/club.entity").Club[]>;
    ranking(limit?: number): Promise<import("./entities/club.entity").Club[]>;
    findOne(id: string): Promise<import("./entities/club.entity").Club>;
    update(id: string, dto: UpdateClubDto, req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/club.entity").Club>;
    addMember(id: string, dto: ManageMemberDto): Promise<import("./entities/club-member.entity").ClubMember>;
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
