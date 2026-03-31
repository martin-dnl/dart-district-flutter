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
    remove(req: {
        user: {
            id: string;
        };
    }): Promise<void>;
}
