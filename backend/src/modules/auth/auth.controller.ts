import {
  Controller,
  Post,
  Body,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { OAuth2Client, TokenPayload } from 'google-auth-library';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { SocialLoginDto } from './dto/social-login.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly configService: ConfigService,
  ) {}

  private readonly googleOAuthClient = new OAuth2Client();

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('google')
  @HttpCode(HttpStatus.OK)
  async googleLogin(@Body() dto: SocialLoginDto) {
    const payload = await this.verifyGoogleIdToken(dto.id_token);
    return this.authService.socialLogin('google', {
      email: payload.email,
      name: payload.name ?? payload.email.split('@')[0],
      provider_uid: payload.sub,
      avatar_url: payload.picture,
    });
  }

  @Post('apple')
  @HttpCode(HttpStatus.OK)
  async appleLogin(@Body() dto: SocialLoginDto) {
    const payload = this.decodeIdToken(dto.id_token);
    return this.authService.socialLogin('apple', {
      email: payload.email,
      name: payload.name ?? payload.email.split('@')[0],
      provider_uid: payload.sub,
    });
  }

  @Post('guest')
  @HttpCode(HttpStatus.OK)
  guestLogin() {
    return this.authService.guestLogin();
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refreshAccessToken(dto.refresh_token);
  }

  @Post('logout')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  logout(@Req() req: { user: { id: string } }) {
    return this.authService.logout(req.user.id);
  }

  /** Decode JWT id_token payload (base64). Verification should use provider SDK in production. */
  private decodeIdToken(token: string): Record<string, string> {
    const parts = token.split('.');
    if (parts.length !== 3) throw new Error('Invalid id_token');
    return JSON.parse(Buffer.from(parts[1], 'base64url').toString());
  }

  private async verifyGoogleIdToken(idToken: string): Promise<{
    email: string;
    name?: string;
    sub: string;
    picture?: string;
  }> {
    const rawAudiences =
      this.configService.get<string>('GOOGLE_OAUTH_REQUIRED_CLIENT_IDS') ??
      this.configService.get<string>('GOOGLE_OAUTH_CLIENT_IDS') ??
      this.configService.get<string>('GOOGLE_CLIENT_ID') ??
      '';
    const audiences = rawAudiences
      .split(',')
      .map((value) => value.trim())
      .filter((value) => value.length > 0);

    if (audiences.length === 0) {
      throw new UnauthorizedException('Google OAuth is not configured on server');
    }

    const ticket = await this.googleOAuthClient.verifyIdToken({
      idToken,
      audience: audiences,
    });
    const payload = ticket.getPayload() as TokenPayload | undefined;

    if (!payload?.email || !payload?.sub) {
      throw new UnauthorizedException('Invalid Google token payload');
    }

    if (payload.email_verified !== true) {
      throw new UnauthorizedException('Google account email is not verified');
    }

    return {
      email: payload.email,
      name: payload.name,
      sub: payload.sub,
      picture: payload.picture,
    };
  }
}
