import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
export declare class UsersController {
    private readonly usersService;
    constructor(usersService: UsersService);
    me(req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/user.entity").User>;
    leaderboard(limit?: number): Promise<import("./entities/user.entity").User[]>;
    search(q: string, limit?: number): Promise<import("./entities/user.entity").User[]>;
    findOne(id: string): Promise<import("./entities/user.entity").User>;
    update(req: {
        user: {
            id: string;
        };
    }, dto: UpdateUserDto): Promise<import("./entities/user.entity").User>;
    uploadAvatar(req: {
        user: {
            id: string;
        };
    }, file?: Express.Multer.File): Promise<{
        avatar_md_url: string;
        avatar_sm_url: string;
        avatar_url: string;
    }>;
    remove(req: {
        user: {
            id: string;
        };
    }): Promise<void>;
}
