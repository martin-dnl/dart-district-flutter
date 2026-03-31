import { Repository } from 'typeorm';
import { User } from './entities/user.entity';
import { UpdateUserDto } from './dto/update-user.dto';
export declare class UsersService {
    private readonly repo;
    constructor(repo: Repository<User>);
    findById(id: string): Promise<User>;
    update(id: string, dto: UpdateUserDto): Promise<User>;
    search(query: string, limit?: number): Promise<User[]>;
    leaderboard(limit?: number): Promise<User[]>;
    remove(id: string): Promise<void>;
}
