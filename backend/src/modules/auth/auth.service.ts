import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  Logger,
  BadRequestException,
  BadGatewayException,
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
import { SsoCompleteDto } from './dto/sso-complete.dto';
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
    // 1. Existing link by provider_uid
    const linkedProvider = await this.authProviderRepo.findOne({
      where: { provider, provider_uid: payload.provider_uid },
      relations: ['user'],
    });

    if (linkedProvider?.user) {
      const tokens = await this.generateTokens(linkedProvider.user);
      const needsOnboarding = linkedProvider.user.username.startsWith('Joueur_');
      return { ...tokens, is_new_user: false, needs_onboarding: needsOnboarding, email: linkedProvider.user.email, provider };
    }

    // 2. Existing user by email (link the provider)
    const existingUser = await this.userRepo.findOne({ where: { email: payload.email } });
    if (existingUser) {
      const existingAp = await this.authProviderRepo.findOne({
        where: { user: { id: existingUser.id }, provider },
      });
      if (!existingAp) {
        const ap = this.authProviderRepo.create({ user: existingUser, provider, provider_uid: payload.provider_uid });
        await this.authProviderRepo.save(ap);
      }
      const tokens = await this.generateTokens(existingUser);
      const needsOnboarding = existingUser.username.startsWith('Joueur_');
      return { ...tokens, is_new_user: false, needs_onboarding: needsOnboarding, email: existingUser.email, provider };
    }

    // 3. Brand-new user: issue a short-lived pending token – NO DB write.
    const sso_token = this.jwtService.sign(
      { type: 'sso_pending', email: payload.email, name: payload.name, provider_uid: payload.provider_uid, provider },
      { expiresIn: '30m' },
    );

    return { needs_registration: true, sso_token, email: payload.email, name: payload.name };
  }

  /* ───── Complete SSO Registration ───── */
  async completeSsoRegistration(dto: SsoCompleteDto) {
    let pending: { type?: string; email: string; name: string; provider_uid: string; provider: string };
    try {
      pending = this.jwtService.verify(dto.sso_token) as typeof pending;
    } catch {
      throw new UnauthorizedException('Token d\'inscription SSO invalide ou expire. Recommencez la connexion Google.');
    }

    if (pending.type !== 'sso_pending') {
      throw new UnauthorizedException('Type de token SSO invalide');
    }

    // Guard: if account already exists from a concurrent attempt, just return tokens.
    const existingProvider = await this.authProviderRepo.findOne({
      where: { provider: pending.provider as 'google' | 'apple', provider_uid: pending.provider_uid },
      relations: ['user'],
    });
    if (existingProvider?.user) {
      return this.generateTokens(existingProvider.user);
    }

    const existingByEmail = await this.userRepo.findOne({ where: { email: pending.email } });
    if (existingByEmail) {
      const ap = this.authProviderRepo.create({ user: existingByEmail, provider: pending.provider as 'google' | 'apple', provider_uid: pending.provider_uid });
      await this.authProviderRepo.save(ap).catch(() => { /* ignore duplicate */ });
      return this.generateTokens(existingByEmail);
    }

    const username = dto.display_name.trim();
    const existingUsername = await this.userRepo.findOne({ where: { username } });
    if (existingUsername) {
      throw new ConflictException('Ce pseudo est deja utilise. Choisissez-en un autre.');
    }

    const user = this.userRepo.create({
      username,
      email: pending.email,
      level: dto.level ?? 'intermediate',
      preferred_hand: (dto.preferred_hand ?? 'right') as 'right' | 'left',
    });
    await this.userRepo.save(user);

    const ap = this.authProviderRepo.create({ user, provider: pending.provider as 'google' | 'apple', provider_uid: pending.provider_uid });
    await this.authProviderRepo.save(ap);

    return this.generateTokens(user);
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
      is_admin: user.is_admin,
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
