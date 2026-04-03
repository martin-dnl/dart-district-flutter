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
  async socialLogin(provider: 'google' | 'apple', payload: { email: string; name: string; provider_uid: string }) {
    const linkedProvider = await this.authProviderRepo.findOne({
      where: { provider, provider_uid: payload.provider_uid },
      relations: ['user'],
    });

    let user = linkedProvider?.user ?? null;

    if (!user) {
      user = await this.userRepo.findOne({ where: { email: payload.email } });
    }

    let isNewUser = false;

    if (!user) {
      isNewUser = true;
      // Use a random temporary username; user will pick their real one after SSO.
      // Include more entropy to avoid UNIQUE constraint collisions.
      const tempUsername = `Joueur_${randomUUID().slice(0, 8)}`;
      user = this.userRepo.create({
        username: tempUsername,
        email: payload.email,
      });
      try {
        await this.userRepo.save(user);
      } catch (saveError: unknown) {
        // Handle race condition: user may have been created concurrently.
        const msg = saveError instanceof Error ? saveError.message : '';
        if (msg.includes('duplicate') || msg.includes('unique') || msg.includes('23505')) {
          const retryUser = await this.userRepo.findOne({ where: { email: payload.email } });
          if (retryUser) {
            user = retryUser;
            isNewUser = false;
          } else {
            throw saveError;
          }
        } else {
          throw saveError;
        }
      }
    }

    if (!linkedProvider) {
      const existingAp = await this.authProviderRepo.findOne({
        where: { user: { id: user.id }, provider },
      });

      if (existingAp && existingAp.provider_uid !== payload.provider_uid) {
        throw new UnauthorizedException('Social account mismatch for this user');
      }

      if (!existingAp) {
        try {
          const ap = this.authProviderRepo.create({
            user,
            provider,
            provider_uid: payload.provider_uid,
          });
          await this.authProviderRepo.save(ap);
        } catch (apError: unknown) {
          // Ignore duplicate auth_provider (race condition or retry).
          const msg = apError instanceof Error ? apError.message : '';
          if (!(msg.includes('duplicate') || msg.includes('unique') || msg.includes('23505'))) {
            throw apError;
          }
        }
      }
    }

    const tokens = await this.generateTokens(user);
    const needsOnboarding = user.username.startsWith('Joueur_');

    return {
      ...tokens,
      is_new_user: isNewUser,
      needs_onboarding: needsOnboarding,
      email: user.email,
      provider,
    };
  }

  /* ───── Guest Login ───── */
  async guestLogin() {
    const payload: JwtPayload = {
      sub: 'guest',
      email: '',
      username: 'Invité',
      is_guest: true,
    };

    const access_token = this.jwtService.sign(payload, {
      expiresIn: '24h',
    });

    return { access_token, refresh_token: '' };
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
