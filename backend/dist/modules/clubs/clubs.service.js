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
exports.ClubsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const club_entity_1 = require("./entities/club.entity");
const club_member_entity_1 = require("./entities/club-member.entity");
const normalize_limit_1 = require("../../common/utils/normalize-limit");
let ClubsService = class ClubsService {
    constructor(clubRepo, memberRepo, dataSource) {
        this.clubRepo = clubRepo;
        this.memberRepo = memberRepo;
        this.dataSource = dataSource;
    }
    async create(dto, userId) {
        let resolvedCodeIris = dto.code_iris ?? null;
        if (!resolvedCodeIris && dto.latitude != null && dto.longitude != null) {
            resolvedCodeIris = await this.resolveNearestCodeIris(dto.latitude, dto.longitude);
        }
        const club = this.clubRepo.create(dto);
        club.code_iris = resolvedCodeIris;
        await this.clubRepo.save(club);
        const membership = this.memberRepo.create({
            club,
            user: { id: userId },
            role: 'president',
        });
        await this.memberRepo.save(membership);
        return this.findById(club.id);
    }
    async findAll(limit = 50, q, city) {
        const take = (0, normalize_limit_1.normalizeLimit)(limit, 50);
        const qb = this.clubRepo
            .createQueryBuilder('club')
            .leftJoinAndSelect('club.members', 'members')
            .orderBy('club.conquest_points', 'DESC')
            .take(take);
        if (q) {
            qb.andWhere('(club.name ILIKE :q OR club.city ILIKE :q)', {
                q: `%${q}%`,
            });
        }
        if (city) {
            qb.andWhere('club.city ILIKE :city', { city: `%${city}%` });
        }
        return qb.getMany();
    }
    async search(params) {
        const queryValue = (params.q ?? '').trim().toLowerCase();
        const likeTerm = `%${queryValue}%`;
        const take = (0, normalize_limit_1.normalizeLimit)(params.limit ?? 20, 50);
        const hasGeo = Number.isFinite(params.lat) && Number.isFinite(params.lng);
        const radiusKm = Number.isFinite(params.radius) && (params.radius ?? 0) > 0
            ? Number(params.radius)
            : 20;
        const qb = this.clubRepo
            .createQueryBuilder('club')
            .leftJoinAndSelect('club.members', 'members')
            .take(take);
        if (queryValue.length > 0) {
            qb.andWhere('(LOWER(club.name) LIKE :q OR LOWER(club.city) LIKE :q)', {
                q: likeTerm,
            });
        }
        if (hasGeo) {
            const lat = Number(params.lat);
            const lng = Number(params.lng);
            const distanceExpr = `(
        6371 * acos(
          cos(radians(:lat)) *
          cos(radians(CAST(club.latitude AS double precision))) *
          cos(radians(CAST(club.longitude AS double precision)) - radians(:lng)) +
          sin(radians(:lat)) * sin(radians(CAST(club.latitude AS double precision)))
        )
      )`;
            qb.andWhere('club.latitude IS NOT NULL AND club.longitude IS NOT NULL')
                .addSelect(distanceExpr, 'distance')
                .andWhere(`${distanceExpr} <= :radiusKm`)
                .setParameters({ lat, lng, radiusKm })
                .orderBy('distance', 'ASC');
        }
        else {
            qb.orderBy('club.name', 'ASC');
        }
        return qb.getMany();
    }
    async findById(id) {
        const club = await this.clubRepo.findOne({
            where: { id },
            relations: ['members', 'members.user'],
        });
        if (!club)
            throw new common_1.NotFoundException('Club not found');
        return club;
    }
    async update(id, dto, userId) {
        await this.assertRole(id, userId, ['president']);
        await this.clubRepo.update(id, dto);
        return this.findById(id);
    }
    async addMember(clubId, userId, role = 'player') {
        const existing = await this.memberRepo.findOne({
            where: { club: { id: clubId }, user: { id: userId } },
        });
        if (existing)
            throw new common_1.ConflictException('User is already a member');
        const membership = this.memberRepo.create({
            club: { id: clubId },
            user: { id: userId },
            role,
        });
        return this.memberRepo.save(membership);
    }
    async removeMember(clubId, targetUserId, requesterId) {
        if (targetUserId !== requesterId) {
            await this.assertRole(clubId, requesterId, ['president', 'captain']);
        }
        const result = await this.memberRepo.delete({
            club: { id: clubId },
            user: { id: targetUserId },
        });
        if (result.affected === 0)
            throw new common_1.NotFoundException('Membership not found');
    }
    async updateMemberRole(clubId, targetUserId, role, requesterId) {
        await this.assertRole(clubId, requesterId, ['president']);
        const membership = await this.memberRepo.findOne({
            where: { club: { id: clubId }, user: { id: targetUserId } },
        });
        if (!membership)
            throw new common_1.NotFoundException('Membership not found');
        membership.role = role;
        return this.memberRepo.save(membership);
    }
    async ranking(limit = 50) {
        const take = (0, normalize_limit_1.normalizeLimit)(limit, 50);
        return this.clubRepo.find({
            order: { conquest_points: 'DESC' },
            take,
            select: ['id', 'name', 'conquest_points', 'rank'],
        });
    }
    async findForMap() {
        const clubs = await this.clubRepo.find({
            where: {},
            select: ['id', 'name', 'latitude', 'longitude', 'code_iris', 'city'],
            order: { name: 'ASC' },
        });
        return clubs
            .filter((club) => club.latitude != null && club.longitude != null)
            .map((club) => ({
            id: club.id,
            name: club.name,
            latitude: Number(club.latitude),
            longitude: Number(club.longitude),
            code_iris: club.code_iris,
            city: club.city,
        }));
    }
    async resolveNearestCodeIris(latitude, longitude) {
        const rows = await this.dataSource.query(`
        SELECT code_iris
        FROM territories
        ORDER BY (
          POWER((CAST(centroid_lat AS double precision) - $1), 2) +
          POWER((CAST(centroid_lng AS double precision) - $2), 2)
        ) ASC
        LIMIT 1
      `, [latitude, longitude]);
        const code = rows?.[0]?.code_iris;
        return typeof code === 'string' && code.length > 0 ? code : null;
    }
    async assertRole(clubId, userId, roles) {
        const m = await this.memberRepo.findOne({
            where: { club: { id: clubId }, user: { id: userId } },
        });
        if (!m || !roles.includes(m.role)) {
            throw new common_1.ForbiddenException('Insufficient club privileges');
        }
    }
};
exports.ClubsService = ClubsService;
exports.ClubsService = ClubsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(club_entity_1.Club)),
    __param(1, (0, typeorm_1.InjectRepository)(club_member_entity_1.ClubMember)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.DataSource])
], ClubsService);
//# sourceMappingURL=clubs.service.js.map