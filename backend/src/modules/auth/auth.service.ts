import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  Logger,
  BadRequestException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';
import { User } from '../users/entities/user.entity';
import { AuthProvider } from './entities/auth-provider.entity';
import { RefreshToken } from './entities/refresh-token.entity';
import { RegisterDto, RegisterProvider } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { JwtPayload } from './strategies/jwt.strategy';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(AuthProvider) private readonly authProviderRepo: Repository<AuthProvider>,
    @InjectRepository(RefreshToken) private readonly refreshTokenRepo: Repository<RefreshToken>,
    private readonly jwtService: JwtService,
  ) {}

  /* ───── Register (local) ───── */
  async register(dto: RegisterDto) {
    const provider = dto.provider ?? RegisterProvider.LOCAL;
    const normalizedEmail = dto.email?.trim().toLowerCase();

    if (provider === RegisterProvider.LOCAL && !dto.password) {
      throw new BadRequestException('Password is required for local registration');
    }

    if (provider !== RegisterProvider.GUEST && !normalizedEmail) {
      throw new BadRequestException('Email is required for this registration provider');
    }

    if (normalizedEmail) {
      const existing = await this.userRepo.findOne({
        where: { email: normalizedEmail },
      });
      if (existing) throw new ConflictException('Email already in use');
    }

    const username = dto.display_name.trim();
    const passwordHash =
      provider === RegisterProvider.LOCAL && dto.password
        ? await bcrypt.hash(dto.password, 12)
        : null;

    const user = this.userRepo.create({
      username,
      email: normalizedEmail ?? null,
      avatar_url: dto.avatar_url ?? null,
      is_guest: provider === RegisterProvider.GUEST,
      password_hash: passwordHash,
    });
    await this.userRepo.save(user);

    if (provider === RegisterProvider.LOCAL) {
      const ap = this.authProviderRepo.create({
        user,
        provider: 'local',
        provider_uid: user.id,
      });
      await this.authProviderRepo.save(ap);
    }

    return this.generateTokens(user);
  }

  /* ───── Login (email + password) ───── */
  async login(dto: LoginDto) {
    const user = await this.userRepo
      .createQueryBuilder('user')
      .addSelect('user.password_hash')
      .where('user.email = :email', { email: dto.email })
      .getOne();
    if (!user) throw new UnauthorizedException('Invalid credentials');

    if (!user.password_hash) throw new UnauthorizedException('Invalid credentials');

    const valid = await bcrypt.compare(dto.password, user.password_hash);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    return this.generateTokens(user);
  }

  /* ───── Social Login (Google / Apple) ───── */
  async socialLogin(provider: 'google' | 'apple', payload: { email: string; name: string; provider_uid: string; avatar_url?: string }) {
    let user = await this.userRepo.findOne({ where: { email: payload.email } });

    if (!user) {
      user = this.userRepo.create({
        username: payload.name,
        email: payload.email,
        avatar_url: payload.avatar_url ?? null,
      });
      await this.userRepo.save(user);
    }

    const existingAp = await this.authProviderRepo.findOne({
      where: { user: { id: user.id }, provider },
    });

    if (!existingAp) {
      const ap = this.authProviderRepo.create({
        user,
        provider,
        provider_uid: payload.provider_uid,
      });
      await this.authProviderRepo.save(ap);
    }

    return this.generateTokens(user);
  }

  /* ───── Guest Login ───── */
  async guestLogin() {
    const guestName = `Joueur_${randomUUID().slice(0, 6)}`;
    const user = this.userRepo.create({ username: guestName, is_guest: true });
    await this.userRepo.save(user);

    const ap = this.authProviderRepo.create({
      user,
      provider: 'guest',
      provider_uid: user.id,
    });
    await this.authProviderRepo.save(ap);

    return this.generateTokens(user);
  }

  /* ───── Refresh Token ───── */
  async refreshAccessToken(token: string) {
    const stored = await this.refreshTokenRepo.findOne({
      where: { token },
      relations: ['user'],
    });

    if (!stored || stored.revoked || stored.expires_at < new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    // Rotation: revoke old, issue new pair
    stored.revoked = true;
    await this.refreshTokenRepo.save(stored);

    return this.generateTokens(stored.user);
  }

  /* ───── Logout ───── */
  async logout(userId: string) {
    await this.refreshTokenRepo.update(
      { user: { id: userId }, revoked: false },
      { revoked: true },
    );
  }

  /* ───── Helpers ───── */
  private async generateTokens(user: User) {
    const payload: JwtPayload = {
      sub: user.id,
      email: user.email ?? '',
      username: user.username,
    };

    const access_token = this.jwtService.sign(payload);
    const refresh_token = randomUUID();

    const rt = this.refreshTokenRepo.create({
      user,
      token: refresh_token,
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
    });
    await this.refreshTokenRepo.save(rt);

    return { access_token, refresh_token, user_id: user.id };
  }
}
