import { ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { SocialLoginDto } from './dto/social-login.dto';
import { SsoCompleteDto } from './dto/sso-complete.dto';
export declare class AuthController {
    private readonly authService;
    private readonly configService;
    private readonly logger;
    constructor(authService: AuthService, configService: ConfigService);
    private readonly googleOAuthClient;
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
    googleLogin(dto: SocialLoginDto): Promise<{
        is_new_user: boolean;
        needs_onboarding: boolean;
        email: string | null;
        provider: "google" | "apple";
        access_token: string;
        refresh_token: `${string}-${string}-${string}-${string}-${string}`;
        user_id: string;
        needs_registration?: undefined;
        sso_token?: undefined;
        name?: undefined;
    } | {
        needs_registration: boolean;
        sso_token: string;
        email: string;
        name: string;
    }>;
    appleLogin(dto: SocialLoginDto): Promise<{
        is_new_user: boolean;
        needs_onboarding: boolean;
        email: string | null;
        provider: "google" | "apple";
        access_token: string;
        refresh_token: `${string}-${string}-${string}-${string}-${string}`;
        user_id: string;
        needs_registration?: undefined;
        sso_token?: undefined;
        name?: undefined;
    } | {
        needs_registration: boolean;
        sso_token: string;
        email: string;
        name: string;
    }>;
    guestLogin(): Promise<{
        access_token: string;
        refresh_token: string;
    }>;
    ssoComplete(dto: SsoCompleteDto): Promise<{
        access_token: string;
        refresh_token: `${string}-${string}-${string}-${string}-${string}`;
        user_id: string;
    }>;
    refresh(dto: RefreshTokenDto): Promise<{
        access_token: string;
        refresh_token: `${string}-${string}-${string}-${string}-${string}`;
        user_id: string;
    }>;
    logout(req: {
        user: {
            id: string;
        };
    }): Promise<void>;
    private decodeIdToken;
    private verifyGoogleIdToken;
    private verifyGoogleAccessToken;
    private fetchGoogleUserInfo;
}
