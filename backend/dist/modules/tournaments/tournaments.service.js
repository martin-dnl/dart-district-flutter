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
exports.TournamentsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const tournament_entity_1 = require("./entities/tournament.entity");
const tournament_registration_entity_1 = require("./entities/tournament-registration.entity");
let TournamentsService = class TournamentsService {
    constructor(tournamentRepo, regRepo) {
        this.tournamentRepo = tournamentRepo;
        this.regRepo = regRepo;
    }
    async create(dto, userId) {
        const tournament = this.tournamentRepo.create({
            ...dto,
            creator: { id: userId },
        });
        return this.tournamentRepo.save(tournament);
    }
    async findAll() {
        return this.tournamentRepo.find({
            where: { scheduled_at: (0, typeorm_2.MoreThan)(new Date()) },
            relations: ['territory', 'creator'],
            order: { scheduled_at: 'ASC' },
        });
    }
    async findById(id) {
        const t = await this.tournamentRepo.findOne({
            where: { id },
            relations: ['territory', 'creator'],
        });
        if (!t)
            throw new common_1.NotFoundException('Tournament not found');
        const registrations = await this.regRepo.find({
            where: { tournament_id: id },
            relations: ['club', 'registrant'],
        });
        return { ...t, registrations };
    }
    async registerClub(tournamentId, clubId, userId) {
        const tournament = await this.findById(tournamentId);
        const registrations = await this.regRepo.find({
            where: { tournament_id: tournamentId },
            relations: ['club'],
        });
        if (registrations.length >= tournament.max_clubs) {
            throw new common_1.BadRequestException('Tournament is full');
        }
        const existing = registrations.find((registration) => registration.club_id === clubId);
        if (existing)
            throw new common_1.BadRequestException('Club already registered');
        const reg = this.regRepo.create({
            tournament_id: tournamentId,
            club_id: clubId,
            registered_by: userId,
        });
        const saved = await this.regRepo.save(reg);
        await this.tournamentRepo.update(tournamentId, {
            enrolled_clubs: registrations.length + 1,
        });
        return saved;
    }
    async unregisterClub(tournamentId, clubId) {
        const result = await this.regRepo.delete({
            tournament_id: tournamentId,
            club_id: clubId,
        });
        if (result.affected === 0)
            throw new common_1.NotFoundException('Registration not found');
        const remaining = await this.regRepo.count({
            where: { tournament_id: tournamentId },
        });
        await this.tournamentRepo.update(tournamentId, { enrolled_clubs: remaining });
    }
};
exports.TournamentsService = TournamentsService;
exports.TournamentsService = TournamentsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(tournament_entity_1.Tournament)),
    __param(1, (0, typeorm_1.InjectRepository)(tournament_registration_entity_1.TournamentRegistration)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository])
], TournamentsService);
//# sourceMappingURL=tournaments.service.js.map