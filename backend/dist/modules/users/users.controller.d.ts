import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
export declare class UsersController {
    private readonly usersService;
    constructor(usersService: UsersService);
    me(req: {
        user: {
            id: string;
            is_guest?: boolean;
            username?: string;
        };
    }): Promise<import("./entities/user.entity").User> | {
        id: string;
        username: string;
        email: null;
        avatar_url: null;
        elo: number;
        is_admin: boolean;
        created_at: string;
        stats: {
            matches_played: number;
            matches_won: number;
            avg_score: number;
            checkout_rate: number;
            total_180s: number;
            count_140_plus: number;
            count_100_plus: number;
            best_avg: number;
        };
        club_memberships: never[];
    };
    myBadges(req: {
        user: {
            id: string;
        };
    }): Promise<import("../badges/entities/user-badge.entity").UserBadge[]>;
    mySettings(req: {
        user: {
            id: string;
            is_guest?: boolean;
        };
    }, key?: string): Promise<{
        key: string;
        value: string;
    }[] | {
        key: string;
        value: string | null;
    }>;
    leaderboard(limit?: number): Promise<import("./entities/user.entity").User[]>;
    search(q: string, limit?: number): Promise<import("./entities/user.entity").User[]>;
    findOne(id: string): Promise<import("./entities/user.entity").User>;
    update(req: {
        user: {
            id: string;
            is_guest?: boolean;
        };
    }, dto: UpdateUserDto): Promise<import("./entities/user.entity").User>;
    updateSetting(req: {
        user: {
            id: string;
            is_guest?: boolean;
        };
    }, body: {
        key?: string;
        value?: string;
    }): Promise<{
        key: string;
        value: string;
    }>;
    uploadAvatar(req: {
        user: {
            id: string;
            is_guest?: boolean;
        };
    }, file?: Express.Multer.File): Promise<{
        avatar_md_url: string;
        avatar_sm_url: string;
        avatar_url: string;
    }>;
    remove(req: {
        user: {
            id: string;
            is_guest?: boolean;
        };
    }): Promise<{
        success: boolean;
    }>;
}
