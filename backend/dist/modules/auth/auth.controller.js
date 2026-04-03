"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
var AuthController_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthController = void 0;
const common_1 = require("@nestjs/common");
const https = require("https");
const config_1 = require("@nestjs/config");
const swagger_1 = require("@nestjs/swagger");
const google_auth_library_1 = require("google-auth-library");
const auth_service_1 = require("./auth.service");
const register_dto_1 = require("./dto/register.dto");
const login_dto_1 = require("./dto/login.dto");
const refresh_token_dto_1 = require("./dto/refresh-token.dto");
const social_login_dto_1 = require("./dto/social-login.dto");
const sso_complete_dto_1 = require("./dto/sso-complete.dto");
const jwt_auth_guard_1 = require("./guards/jwt-auth.guard");
let AuthController = AuthController_1 = class AuthController {
    constructor(authService, configService) {
        this.authService = authService;
        this.configService = configService;
        this.logger = new common_1.Logger(AuthController_1.name);
        this.googleOAuthClient = new google_auth_library_1.OAuth2Client();
    }
    register(dto) {
        return this.authService.register(dto);
    }
    login(dto) {
        return this.authService.login(dto);
    }
    async googleLogin(dto) {
        let payload = null;
        try {
            if (dto.id_token) {
                try {
                    payload = await this.verifyGoogleIdToken(dto.id_token);
                }
                catch (error) {
                    this.logger.warn(`Google id_token verification failed: ${error instanceof Error ? error.message : error}`);
                    if (dto.access_token) {
                        payload = await this.verifyGoogleAccessToken(dto.access_token);
                    }
                    else {
                        throw error;
                    }
                }
            }
            else if (dto.access_token) {
                payload = await this.verifyGoogleAccessToken(dto.access_token);
            }
            if (!payload) {
                throw new common_1.UnauthorizedException('Missing Google token payload');
            }
            this.logger.log(`Google auth verified for ${payload.email} (sub=${payload.sub})`);
            return await this.authService.socialLogin('google', {
                email: payload.email,
                name: payload.name ?? payload.email.split('@')[0],
                provider_uid: payload.sub,
            });
        }
        catch (error) {
            if (error instanceof common_1.UnauthorizedException) {
                throw error;
            }
            const detail = error instanceof Error
                ? `${error.constructor.name}: ${error.message}`
                : String(error);
            this.logger.error(`Google login failed: ${detail}`, error instanceof Error ? error.stack : undefined);
            throw new common_1.InternalServerErrorException(`Google login failed: ${detail}`);
        }
    }
    async appleLogin(dto) {
        if (!dto.id_token) {
            throw new common_1.UnauthorizedException('Missing Apple id_token');
        }
        const payload = this.decodeIdToken(dto.id_token);
        return this.authService.socialLogin('apple', {
            email: payload.email,
            name: payload.name ?? payload.email.split('@')[0],
            provider_uid: payload.sub,
        });
    }
    guestLogin() {
        return this.authService.guestLogin();
    }
    ssoComplete(dto) {
        return this.authService.completeSsoRegistration(dto);
    }
    refresh(dto) {
        return this.authService.refreshAccessToken(dto.refresh_token);
    }
    logout(req) {
        return this.authService.logout(req.user.id);
    }
    decodeIdToken(token) {
        const parts = token.split('.');
        if (parts.length !== 3)
            throw new Error('Invalid id_token');
        return JSON.parse(Buffer.from(parts[1], 'base64url').toString());
    }
    async verifyGoogleIdToken(idToken) {
        const rawAudiences = this.configService.get('GOOGLE_OAUTH_REQUIRED_CLIENT_IDS') ??
            this.configService.get('GOOGLE_OAUTH_CLIENT_IDS') ??
            this.configService.get('GOOGLE_CLIENT_ID') ??
            '';
        const audiences = rawAudiences
            .split(',')
            .map((value) => value.trim())
            .filter((value) => value.length > 0);
        if (audiences.length === 0) {
            throw new common_1.UnauthorizedException('Google OAuth is not configured on server');
        }
        let payload;
        try {
            const ticket = await this.googleOAuthClient.verifyIdToken({
                idToken,
                audience: audiences,
            });
            payload = ticket.getPayload();
        }
        catch {
            throw new common_1.UnauthorizedException('Invalid Google id_token');
        }
        if (!payload?.email || !payload?.sub) {
            throw new common_1.UnauthorizedException('Invalid Google token payload');
        }
        if (payload.email_verified !== true) {
            throw new common_1.UnauthorizedException('Google account email is not verified');
        }
        return {
            email: payload.email,
            name: payload.name,
            sub: payload.sub,
            picture: payload.picture,
        };
    }
    async verifyGoogleAccessToken(accessToken) {
        const payload = await this.fetchGoogleUserInfo(accessToken);
        if (!payload?.email || !payload?.sub) {
            throw new common_1.UnauthorizedException('Invalid Google token payload');
        }
        if (payload.email_verified !== true) {
            throw new common_1.UnauthorizedException('Google account email is not verified');
        }
        return {
            email: payload.email,
            name: payload.name,
            sub: payload.sub,
            picture: payload.picture,
        };
    }
    fetchGoogleUserInfo(accessToken) {
        return new Promise((resolve, reject) => {
            const req = https.request('https://openidconnect.googleapis.com/v1/userinfo', {
                method: 'GET',
                headers: {
                    Authorization: `Bearer ${accessToken}`,
                },
            }, (res) => {
                let raw = '';
                res.setEncoding('utf8');
                res.on('data', (chunk) => {
                    raw += chunk;
                });
                res.on('end', () => {
                    const statusCode = res.statusCode ?? 500;
                    if (statusCode < 200 || statusCode >= 300) {
                        reject(new common_1.UnauthorizedException('Invalid Google access token'));
                        return;
                    }
                    try {
                        const parsed = JSON.parse(raw);
                        resolve(parsed);
                    }
                    catch {
                        reject(new common_1.UnauthorizedException('Invalid Google token payload'));
                    }
                });
            });
            req.on('error', () => {
                reject(new common_1.UnauthorizedException('Unable to verify Google access token'));
            });
            req.end();
        });
    }
};
exports.AuthController = AuthController;
__decorate([
    (0, common_1.Post)('register'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [register_dto_1.RegisterDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "register", null);
__decorate([
    (0, common_1.Post)('login'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [login_dto_1.LoginDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "login", null);
__decorate([
    (0, common_1.Post)('google'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [social_login_dto_1.SocialLoginDto]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "googleLogin", null);
__decorate([
    (0, common_1.Post)('apple'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [social_login_dto_1.SocialLoginDto]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "appleLogin", null);
__decorate([
    (0, common_1.Post)('guest'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "guestLogin", null);
__decorate([
    (0, common_1.Post)('sso/complete'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [sso_complete_dto_1.SsoCompleteDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "ssoComplete", null);
__decorate([
    (0, common_1.Post)('refresh'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [refresh_token_dto_1.RefreshTokenDto]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "refresh", null);
__decorate([
    (0, common_1.Post)('logout'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], AuthController.prototype, "logout", null);
exports.AuthController = AuthController = AuthController_1 = __decorate([
    (0, swagger_1.ApiTags)('auth'),
    (0, common_1.Controller)('auth'),
    __metadata("design:paramtypes", [auth_service_1.AuthService,
        config_1.ConfigService])
], AuthController);
//# sourceMappingURL=auth.controller.js.map