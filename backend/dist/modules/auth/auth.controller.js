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
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthController = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const swagger_1 = require("@nestjs/swagger");
const google_auth_library_1 = require("google-auth-library");
const auth_service_1 = require("./auth.service");
const register_dto_1 = require("./dto/register.dto");
const login_dto_1 = require("./dto/login.dto");
const refresh_token_dto_1 = require("./dto/refresh-token.dto");
const social_login_dto_1 = require("./dto/social-login.dto");
const jwt_auth_guard_1 = require("./guards/jwt-auth.guard");
let AuthController = class AuthController {
    constructor(authService, configService) {
        this.authService = authService;
        this.configService = configService;
        this.googleOAuthClient = new google_auth_library_1.OAuth2Client();
    }
    register(dto) {
        return this.authService.register(dto);
    }
    login(dto) {
        return this.authService.login(dto);
    }
    async googleLogin(dto) {
        const payload = dto.id_token
            ? await this.verifyGoogleIdToken(dto.id_token)
            : dto.access_token
                ? await this.verifyGoogleAccessToken(dto.access_token)
                : null;
        if (!payload) {
            throw new common_1.UnauthorizedException('Missing Google token payload');
        }
        return this.authService.socialLogin('google', {
            email: payload.email,
            name: payload.name ?? payload.email.split('@')[0],
            provider_uid: payload.sub,
        });
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
        const ticket = await this.googleOAuthClient.verifyIdToken({
            idToken,
            audience: audiences,
        });
        const payload = ticket.getPayload();
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
        const response = await fetch('https://openidconnect.googleapis.com/v1/userinfo', {
            headers: {
                Authorization: `Bearer ${accessToken}`,
            },
        });
        if (!response.ok) {
            throw new common_1.UnauthorizedException('Invalid Google access token');
        }
        const payload = (await response.json());
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
exports.AuthController = AuthController = __decorate([
    (0, swagger_1.ApiTags)('auth'),
    (0, common_1.Controller)('auth'),
    __metadata("design:paramtypes", [auth_service_1.AuthService,
        config_1.ConfigService])
], AuthController);
//# sourceMappingURL=auth.controller.js.map