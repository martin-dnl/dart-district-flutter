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