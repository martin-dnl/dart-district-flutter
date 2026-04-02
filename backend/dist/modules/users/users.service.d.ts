import { Repository } from 'typeorm';
import { User } from './entities/user.entity';
import { UpdateUserDto } from './dto/update-user.dto';
import { UserBadge } from '../badges/entities/user-badge.entity';
import { Friendship } from '../contacts/entities/friendship.entity';
import { FriendRequest } from '../contacts/entities/friend-request.entity';
import { RefreshToken } from '../auth/entities/refresh-token.entity';
export declare class UsersService {
    private readonly repo;
    private readonly userBadgeRepo;
    private readonly friendshipRepo;
    private readonly friendRequestRepo;
    private readonly refreshTokenRepo;
    constructor(repo: Repository<User>, userBadgeRepo: Repository<UserBadge>, friendshipRepo: Repository<Friendship>, friendRequestRepo: Repository<FriendRequest>, refreshTokenRepo: Repository<RefreshToken>);
    findById(id: string): Promise<User>;
    update(id: string, dto: UpdateUserDto): Promise<User>;
    findMyBadges(userId: string): Promise<UserBadge[]>;
    uploadAvatar(userId: string, file: Express.Multer.File): Promise<{
        avatar_md_url: string;
        avatar_sm_url: string;
        avatar_url: string;
    }>;
    search(query: string, limit?: number): Promise<User[]>;
    leaderboard(limit?: number): Promise<User[]>;
    remove(id: string): Promise<{
        success: boolean;
    }>;
}
