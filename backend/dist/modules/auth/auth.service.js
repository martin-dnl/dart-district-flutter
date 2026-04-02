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
var AuthService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const common_1 = require("@nestjs/common");
const jwt_1 = require("@nestjs/jwt");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const bcrypt = require("bcrypt");
const crypto_1 = require("crypto");
const user_entity_1 = require("../users/entities/user.entity");
const auth_provider_entity_1 = require("./entities/auth-provider.entity");
const refresh_token_entity_1 = require("./entities/refresh-token.entity");
const register_dto_1 = require("./dto/register.dto");
let AuthService = AuthService_1 = class AuthService {
    constructor(userRepo, authProviderRepo, refreshTokenRepo, jwtService) {
        this.userRepo = userRepo;
        this.authProviderRepo = authProviderRepo;
        this.refreshTokenRepo = refreshTokenRepo;
        this.jwtService = jwtService;
        this.logger = new common_1.Logger(AuthService_1.name);
    }
    async register(dto) {
        const provider = dto.provider ?? register_dto_1.RegisterProvider.LOCAL;
        const normalizedEmail = dto.email?.trim().toLowerCase();
        if (provider === register_dto_1.RegisterProvider.LOCAL && !dto.password) {
            throw new common_1.BadRequestException('Password is required for local registration');
        }
        if (provider !== register_dto_1.RegisterProvider.GUEST && !normalizedEmail) {
            throw new common_1.BadRequestException('Email is required for this registration provider');
        }
        if (normalizedEmail) {
            const existing = await this.userRepo.findOne({
                where: { email: normalizedEmail },
            });
            if (existing)
                throw new common_1.ConflictException('Email already in use');
        }
        const username = dto.display_name.trim();
        const passwordHash = provider === register_dto_1.RegisterProvider.LOCAL && dto.password
            ? await bcrypt.hash(dto.password, 12)
            : null;
        const user = this.userRepo.create({
            username,
            email: normalizedEmail ?? null,
            avatar_url: dto.avatar_url ?? null,
            is_guest: provider === register_dto_1.RegisterProvider.GUEST,
            password_hash: passwordHash,
        });
        await this.userRepo.save(user);
        if (provider === register_dto_1.RegisterProvider.LOCAL) {
            const ap = this.authProviderRepo.create({
                user,
                provider: 'local',
                provider_uid: user.id,
            });
            await this.authProviderRepo.save(ap);
        }
        return this.generateTokens(user);
    }
    async login(dto) {
        const user = await this.userRepo
            .createQueryBuilder('user')
            .addSelect('user.password_hash')
            .where('user.email = :email', { email: dto.email })
            .getOne();
        if (!user)
            throw new common_1.UnauthorizedException('Invalid credentials');
        if (!user.password_hash)
            throw new common_1.UnauthorizedException('Invalid credentials');
        const valid = await bcrypt.compare(dto.password, user.password_hash);
        if (!valid)
            throw new common_1.UnauthorizedException('Invalid credentials');
        return this.generateTokens(user);
    }
    async socialLogin(provider, payload) {
        let user = await this.userRepo.findOne({ where: { email: payload.email } });
        let isNewUser = false;
        if (!user) {
            isNewUser = true;
            const tempUsername = `Joueur_${(0, crypto_1.randomUUID)().slice(0, 6)}`;
            user = this.userRepo.create({
                username: tempUsername,
                email: payload.email,
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
        const tokens = await this.generateTokens(user);
        return { ...tokens, is_new_user: isNewUser };
    }
    async guestLogin() {
        const guestName = `Joueur_${(0, crypto_1.randomUUID)().slice(0, 6)}`;
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
    async refreshAccessToken(token) {
        const stored = await this.refreshTokenRepo.findOne({
            where: { token },
            relations: ['user'],
        });
        if (!stored || stored.revoked || stored.expires_at < new Date()) {
            throw new common_1.UnauthorizedException('Invalid or expired refresh token');
        }
        stored.revoked = true;
        await this.refreshTokenRepo.save(stored);
        return this.generateTokens(stored.user);
    }
    async logout(userId) {
        await this.refreshTokenRepo.update({ user: { id: userId }, revoked: false }, { revoked: true });
    }
    async generateTokens(user) {
        const payload = {
            sub: user.id,
            email: user.email ?? '',
            username: user.username,
        };
        const access_token = this.jwtService.sign(payload);
        const refresh_token = (0, crypto_1.randomUUID)();
        const rt = this.refreshTokenRepo.create({
            user,
            token: refresh_token,
            expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        });
        await this.refreshTokenRepo.save(rt);
        return { access_token, refresh_token, user_id: user.id };
    }
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = AuthService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __param(1, (0, typeorm_1.InjectRepository)(auth_provider_entity_1.AuthProvider)),
    __param(2, (0, typeorm_1.InjectRepository)(refresh_token_entity_1.RefreshToken)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        jwt_1.JwtService])
], AuthService);
//# sourceMappingURL=auth.service.js.map