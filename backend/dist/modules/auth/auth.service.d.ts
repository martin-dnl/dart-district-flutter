import { JwtService } from '@nestjs/jwt';
import { Repository } from 'typeorm';
import { User } from '../users/entities/user.entity';
import { AuthProvider } from './entities/auth-provider.entity';
import { RefreshToken } from './entities/refresh-token.entity';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
export declare class AuthService {
    private readonly userRepo;
    private readonly authProviderRepo;
    private readonly refreshTokenRepo;
    private readonly jwtService;
    private readonly logger;
    constructor(userRepo: Repository<User>, authProviderRepo: Repository<AuthProvider>, refreshTokenRepo: Repository<RefreshToken>, jwtService: JwtService);
    register(dto: RegisterDto): Promise<{
        access_token: string;
        refresh_token: `${string}-${string}-${string}-${string}-${string}`;
        user_id: string;
    }>;
    login(dto: LoginDto): Promise<{
        access_token: string;
        refresh_token: `${string}-${string}-${string}-${string}-${string}`;
        user_id: string;
    }>;
    socialLogin(provider: 'google' | 'apple', payload: {
        email: string;
        name: string;
        provider_uid: string;
        avatar_url?: string;
    }): Promise<{
        access_token: string;
        refresh_token: `${string}-${string}-${string}-${string}-${string}`;
        user_id: string;
    }>;
    guestLogin(): Promise<{
        access_token: string;
        refresh_token: `${string}-${string}-${string}-${string}-${string}`;
        user_id: string;
    }>;
    refreshAccessToken(token: string): Promise<{
        access_token: string;
        refresh_token: `${string}-${string}-${string}-${string}-${string}`;
        user_id: string;
    }>;
    logout(userId: string): Promise<void>;
    private generateTokens;
}
