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
exports.UsersService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const crypto_1 = require("crypto");
const sharp_1 = require("sharp");
const promises_1 = require("fs/promises");
const path_1 = require("path");
const user_entity_1 = require("./entities/user.entity");
const normalize_limit_1 = require("../../common/utils/normalize-limit");
let UsersService = class UsersService {
    constructor(repo) {
        this.repo = repo;
    }
    async findById(id) {
        const user = await this.repo.findOne({
            where: { id },
            relations: ['stats', 'club_memberships', 'club_memberships.club'],
        });
        if (!user)
            throw new common_1.NotFoundException('User not found');
        return user;
    }
    async update(id, dto) {
        await this.repo.update(id, dto);
        return this.findById(id);
    }
    async uploadAvatar(userId, file) {
        const user = await this.repo.findOne({ where: { id: userId } });
        if (!user) {
            throw new common_1.NotFoundException('User not found');
        }
        const allowedMimeTypes = new Set([
            'image/jpeg',
            'image/png',
            'image/webp',
        ]);
        if (!allowedMimeTypes.has(file.mimetype)) {
            throw new common_1.BadRequestException('Unsupported file type');
        }
        if (file.size > 5 * 1024 * 1024) {
            throw new common_1.BadRequestException('File exceeds 5MB');
        }
        const avatarId = (0, crypto_1.randomUUID)();
        const uploadsDir = (0, path_1.join)(process.cwd(), 'uploads', 'avatars');
        await (0, promises_1.mkdir)(uploadsDir, { recursive: true });
        const mdFileName = `${avatarId}_md.webp`;
        const smFileName = `${avatarId}_sm.webp`;
        const mdDiskPath = (0, path_1.join)(uploadsDir, mdFileName);
        const smDiskPath = (0, path_1.join)(uploadsDir, smFileName);
        const image = (0, sharp_1.default)(file.buffer, { failOn: 'none' }).rotate();
        await image
            .clone()
            .resize(200, 200, { fit: 'cover', position: 'center' })
            .webp({ quality: 80 })
            .toFile(mdDiskPath);
        await image
            .clone()
            .resize(64, 64, { fit: 'cover', position: 'center' })
            .webp({ quality: 70 })
            .toFile(smDiskPath);
        const mdPublicUrl = `/uploads/avatars/${mdFileName}`;
        const smPublicUrl = `/uploads/avatars/${smFileName}`;
        const oldAvatar = user.avatar_url;
        user.avatar_url = mdPublicUrl;
        await this.repo.save(user);
        if (oldAvatar && oldAvatar.includes('/avatars/')) {
            const oldMdName = oldAvatar.split('/').pop();
            if (oldMdName) {
                const oldSmName = oldMdName.replace('_md.webp', '_sm.webp');
                await Promise.allSettled([
                    (0, promises_1.unlink)((0, path_1.join)(uploadsDir, oldMdName)),
                    (0, promises_1.unlink)((0, path_1.join)(uploadsDir, oldSmName)),
                ]);
            }
        }
        return {
            avatar_md_url: mdPublicUrl,
            avatar_sm_url: smPublicUrl,
            avatar_url: mdPublicUrl,
        };
    }
    async search(query, limit = 20) {
        const take = (0, normalize_limit_1.normalizeLimit)(limit, 20);
        return this.repo
            .createQueryBuilder('u')
            .where('u.username ILIKE :q', { q: `%${query}%` })
            .orderBy('u.elo', 'DESC')
            .take(take)
            .getMany();
    }
    async leaderboard(limit = 50) {
        const take = (0, normalize_limit_1.normalizeLimit)(limit, 50);
        return this.repo.find({
            order: { elo: 'DESC' },
            take,
            select: ['id', 'username', 'avatar_url', 'elo', 'level'],
        });
    }
    async remove(id) {
        const result = await this.repo.softDelete(id);
        if (result.affected === 0)
            throw new common_1.NotFoundException('User not found');
    }
};
exports.UsersService = UsersService;
exports.UsersService = UsersService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], UsersService);
//# sourceMappingURL=users.service.js.map