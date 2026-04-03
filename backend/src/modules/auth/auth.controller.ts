import {
  Controller,
  Post,
  Body,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
  UnauthorizedException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import * as https from 'https';
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
  private readonly logger = new Logger(AuthController.name);

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
    let payload: { email: string; name?: string; sub: string; picture?: string } | null =
      null;

    try {
      if (dto.id_token) {
        try {
          payload = await this.verifyGoogleIdToken(dto.id_token);
        } catch (error) {
          this.logger.warn(
            `Google id_token verification failed: ${error instanceof Error ? error.message : error}`,
          );
          // Fallback to access_token if available.
          if (dto.access_token) {
            payload = await this.verifyGoogleAccessToken(dto.access_token);
          } else {
            throw error;
          }
        }
      } else if (dto.access_token) {
        payload = await this.verifyGoogleAccessToken(dto.access_token);
      }

      if (!payload) {
        throw new UnauthorizedException('Missing Google token payload');
      }

      this.logger.log(
        `Google auth verified for ${payload.email} (sub=${payload.sub})`,
      );

      return await this.authService.socialLogin('google', {
        email: payload.email,
        name: payload.name ?? payload.email.split('@')[0],
        provider_uid: payload.sub,
      });
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }

      const detail = error instanceof Error
        ? `${error.constructor.name}: ${error.message}`
        : String(error);
      this.logger.error(`Google login failed: ${detail}`, error instanceof Error ? error.stack : undefined);
      throw new InternalServerErrorException(`Google login failed: ${detail}`);
    }
  }

  @Post('apple')
  @HttpCode(HttpStatus.OK)
  async appleLogin(@Body() dto: SocialLoginDto) {
    if (!dto.id_token) {
      throw new UnauthorizedException('Missing Apple id_token');
    }

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

    let payload: TokenPayload | undefined;
    try {
      const ticket = await this.googleOAuthClient.verifyIdToken({
        idToken,
        audience: audiences,
      });
      payload = ticket.getPayload() as TokenPayload | undefined;
    } catch {
      throw new UnauthorizedException('Invalid Google id_token');
    }

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

  private async verifyGoogleAccessToken(accessToken: string): Promise<{
    email: string;
    name?: string;
    sub: string;
    picture?: string;
  }> {
    const payload = await this.fetchGoogleUserInfo(accessToken);

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

  private fetchGoogleUserInfo(accessToken: string): Promise<{
    sub?: string;
    email?: string;
    email_verified?: boolean;
    name?: string;
    picture?: string;
  }> {
    return new Promise((resolve, reject) => {
      const req = https.request(
        'https://openidconnect.googleapis.com/v1/userinfo',
        {
          method: 'GET',
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        },
        (res) => {
          let raw = '';
          res.setEncoding('utf8');
          res.on('data', (chunk) => {
            raw += chunk;
          });
          res.on('end', () => {
            const statusCode = res.statusCode ?? 500;
            if (statusCode < 200 || statusCode >= 300) {
              reject(new UnauthorizedException('Invalid Google access token'));
              return;
            }

            try {
              const parsed = JSON.parse(raw) as {
                sub?: string;
                email?: string;
                email_verified?: boolean;
                name?: string;
                picture?: string;
              };
              resolve(parsed);
            } catch {
              reject(new UnauthorizedException('Invalid Google token payload'));
            }
          });
        },
      );

      req.on('error', () => {
        reject(new UnauthorizedException('Unable to verify Google access token'));
      });

      req.end();
    });
  }

}
