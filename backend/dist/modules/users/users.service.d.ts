import { Repository } from 'typeorm';
import { User } from './entities/user.entity';
import { UpdateUserDto } from './dto/update-user.dto';
export declare class UsersService {
    private readonly repo;
    constructor(repo: Repository<User>);
    findById(id: string): Promise<User>;
    update(id: string, dto: UpdateUserDto): Promise<User>;
    uploadAvatar(userId: string, file: Express.Multer.File): Promise<{
        avatar_md_url: string;
        avatar_sm_url: string;
        avatar_url: string;
    }>;
    search(query: string, limit?: number): Promise<User[]>;
    leaderboard(limit?: number): Promise<User[]>;
    remove(id: string): Promise<void>;
}
