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
const tournament_player_entity_1 = require("./entities/tournament-player.entity");
const tournament_pool_entity_1 = require("./entities/tournament-pool.entity");
const tournament_pool_standing_entity_1 = require("./entities/tournament-pool-standing.entity");
const tournament_bracket_match_entity_1 = require("./entities/tournament-bracket-match.entity");
let TournamentsService = class TournamentsService {
    constructor(tournamentRepo, playerRepo, poolRepo, standingRepo, bracketRepo) {
        this.tournamentRepo = tournamentRepo;
        this.playerRepo = playerRepo;
        this.poolRepo = poolRepo;
        this.standingRepo = standingRepo;
        this.bracketRepo = bracketRepo;
    }
    async create(dto, userId) {
        const poolCount = dto.format === 'pools_then_elimination' ? (dto.pool_count ?? 4) : null;
        const playersPerPool = dto.format === 'pools_then_elimination' && poolCount
            ? Math.ceil(dto.max_players / poolCount)
            : null;
        const tournament = this.tournamentRepo.create({
            ...dto,
            club_id: dto.club_id ?? null,
            current_phase: 'registration',
            pool_count: poolCount,
            players_per_pool: playersPerPool,
            creator: { id: userId },
        });
        return this.tournamentRepo.save(tournament);
    }
    async findAll(options) {
        const qb = this.tournamentRepo
            .createQueryBuilder('t')
            .leftJoinAndSelect('t.territory', 'territory')
            .leftJoinAndSelect('t.creator', 'creator')
            .leftJoinAndSelect('t.club', 'club')
            .orderBy('t.scheduled_at', 'ASC');
        if (options?.status) {
            qb.andWhere('t.status = :status', { status: options.status });
        }
        if (options?.upcoming === 'true') {
            qb.andWhere('t.scheduled_at > :now', { now: new Date() });
        }
        if (!options?.status && options?.upcoming !== 'false') {
            qb.andWhere('t.scheduled_at > :now', { now: new Date() });
        }
        return qb.getMany();
    }
    async findById(id) {
        const t = await this.tournamentRepo.findOne({
            where: { id },
            relations: ['territory', 'creator', 'club'],
        });
        if (!t)
            throw new common_1.NotFoundException('Tournament not found');
        const players = await this.playerRepo.find({
            where: { tournament_id: id },
            relations: ['user', 'pool'],
            order: { registered_at: 'ASC' },
        });
        return { ...t, players };
    }
    async registerPlayer(tournamentId, userId) {
        const tournament = await this.tournamentRepo.findOne({
            where: { id: tournamentId },
        });
        if (!tournament)
            throw new common_1.NotFoundException('Tournament not found');
        if (tournament.current_phase !== 'registration') {
            throw new common_1.BadRequestException('Registration phase is closed');
        }
        const playerCount = await this.playerRepo.count({
            where: { tournament_id: tournamentId },
        });
        if (playerCount >= tournament.max_players) {
            throw new common_1.BadRequestException('Tournament is full');
        }
        const existing = await this.playerRepo.findOne({
            where: { tournament_id: tournamentId, user_id: userId },
        });
        if (existing)
            throw new common_1.BadRequestException('Player already registered');
        const reg = this.playerRepo.create({
            tournament_id: tournamentId,
            user_id: userId,
            seed: playerCount + 1,
        });
        const saved = await this.playerRepo.save(reg);
        await this.tournamentRepo.update(tournamentId, {
            enrolled_players: playerCount + 1,
        });
        return saved;
    }
    async unregisterPlayer(tournamentId, userId) {
        const tournament = await this.tournamentRepo.findOne({
            where: { id: tournamentId },
        });
        if (!tournament)
            throw new common_1.NotFoundException('Tournament not found');
        if (tournament.current_phase !== 'registration') {
            throw new common_1.BadRequestException('Registration phase is closed');
        }
        const result = await this.playerRepo.delete({
            tournament_id: tournamentId,
            user_id: userId,
        });
        if (result.affected === 0)
            throw new common_1.NotFoundException('Registration not found');
        const remaining = await this.playerRepo.count({
            where: { tournament_id: tournamentId },
        });
        await this.tournamentRepo.update(tournamentId, { enrolled_players: remaining });
    }
    async getPools(tournamentId) {
        return this.poolRepo.find({
            where: { tournament_id: tournamentId },
            relations: ['players', 'players.user'],
            order: { pool_name: 'ASC' },
        });
    }
    async generatePools(tournamentId, userId) {
        const tournament = await this.assertCreator(tournamentId, userId);
        if (tournament.current_phase !== 'registration') {
            throw new common_1.BadRequestException('Pools can only be generated from registration phase');
        }
        const players = await this.playerRepo.find({
            where: { tournament_id: tournamentId, is_disqualified: false },
            relations: ['user'],
            order: { seed: 'ASC' },
        });
        if (players.length < 2) {
            throw new common_1.BadRequestException('Not enough players to generate pools');
        }
        const poolCount = tournament.pool_count ?? 4;
        await this.poolRepo.delete({ tournament_id: tournamentId });
        const pools = Array.from({ length: poolCount }, (_, index) => {
            const label = String.fromCharCode(65 + index);
            return this.poolRepo.create({
                tournament_id: tournamentId,
                pool_name: label,
            });
        });
        const savedPools = await this.poolRepo.save(pools);
        let direction = 1;
        let currentIndex = 0;
        const updates = [];
        const standingRows = [];
        for (const player of players) {
            const pool = savedPools[currentIndex];
            updates.push(this.playerRepo.update(player.id, {
                pool_id: pool.id,
                is_qualified: false,
            }));
            standingRows.push(this.standingRepo.create({
                pool_id: pool.id,
                user_id: player.user_id,
                matches_played: 0,
                matches_won: 0,
                legs_won: 0,
                legs_lost: 0,
                points: 0,
                rank: null,
            }));
            if (direction > 0) {
                if (currentIndex === savedPools.length - 1) {
                    direction = -1;
                }
                else {
                    currentIndex += 1;
                }
            }
            else if (currentIndex === 0) {
                direction = 1;
            }
            else {
                currentIndex -= 1;
            }
        }
        await Promise.all(updates);
        await this.standingRepo.save(standingRows);
        tournament.current_phase = 'pools';
        await this.tournamentRepo.save(tournament);
        return savedPools;
    }
    async getPoolStandings(poolId) {
        return this.standingRepo.find({
            where: { pool_id: poolId },
            relations: ['user'],
            order: { points: 'DESC', rank: 'ASC' },
        });
    }
    async updatePoolResult(_poolId, _matchId) {
        return;
    }
    async generateBracket(tournamentId, userId) {
        const tournament = await this.assertCreator(tournamentId, userId);
        if (tournament.current_phase !== 'pools' && tournament.current_phase !== 'registration') {
            throw new common_1.BadRequestException('Bracket can only be generated from registration or pools phase');
        }
        const players = await this.getQualifiedPlayers(tournament);
        if (players.length < 2) {
            throw new common_1.BadRequestException('Not enough players to generate bracket');
        }
        await this.bracketRepo.delete({ tournament_id: tournamentId });
        const bracketSize = this.nextPowerOfTwo(players.length);
        const firstRoundNumber = bracketSize / 2;
        const bracketSlots = [
            ...players,
            ...Array.from({ length: bracketSize - players.length }, () => null),
        ];
        const firstRoundMatches = [];
        for (let i = 0; i < firstRoundNumber; i += 1) {
            const player1 = bracketSlots[i];
            const player2 = bracketSlots[bracketSize - 1 - i];
            const isBye = !player1 || !player2;
            firstRoundMatches.push(this.bracketRepo.create({
                tournament_id: tournamentId,
                round_number: firstRoundNumber,
                position: i + 1,
                player1_id: player1?.user_id ?? null,
                player2_id: player2?.user_id ?? null,
                winner_id: isBye ? (player1?.user_id ?? player2?.user_id ?? null) : null,
                status: isBye ? 'completed' : 'pending',
                match_id: null,
                scheduled_at: null,
            }));
        }
        const saved = await this.bracketRepo.save(firstRoundMatches);
        let round = firstRoundNumber / 2;
        while (round >= 1) {
            const matchCount = round;
            const rows = [];
            for (let i = 0; i < matchCount; i += 1) {
                rows.push(this.bracketRepo.create({
                    tournament_id: tournamentId,
                    round_number: round,
                    position: i + 1,
                    player1_id: null,
                    player2_id: null,
                    winner_id: null,
                    match_id: null,
                    status: 'pending',
                    scheduled_at: null,
                }));
            }
            await this.bracketRepo.save(rows);
            round /= 2;
        }
        tournament.current_phase = 'bracket';
        await this.tournamentRepo.save(tournament);
        return saved;
    }
    async getBracket(tournamentId) {
        return this.bracketRepo.find({
            where: { tournament_id: tournamentId },
            relations: ['player1', 'player2', 'winner'],
            order: { round_number: 'DESC', position: 'ASC' },
        });
    }
    async advancePhase(tournamentId, userId) {
        const tournament = await this.assertCreator(tournamentId, userId);
        const order = ['registration', 'pools', 'bracket', 'finished'];
        const index = order.indexOf(tournament.current_phase);
        if (index === -1 || index >= order.length - 1) {
            throw new common_1.BadRequestException('Tournament phase cannot be advanced');
        }
        tournament.current_phase = order[index + 1];
        return this.tournamentRepo.save(tournament);
    }
    async disqualifyPlayer(tournamentId, playerId, reason, requesterId) {
        await this.assertCreator(tournamentId, requesterId);
        const player = await this.playerRepo.findOne({
            where: { tournament_id: tournamentId, user_id: playerId },
        });
        if (!player) {
            throw new common_1.NotFoundException('Player not found in tournament');
        }
        await this.playerRepo.update(player.id, {
            is_disqualified: true,
            disqualification_reason: reason,
            is_qualified: false,
        });
    }
    async assertCreator(tournamentId, userId) {
        const tournament = await this.tournamentRepo.findOne({
            where: { id: tournamentId },
        });
        if (!tournament) {
            throw new common_1.NotFoundException('Tournament not found');
        }
        if (tournament.created_by !== userId) {
            throw new common_1.ForbiddenException('Only tournament creator can perform this action');
        }
        return tournament;
    }
    async getQualifiedPlayers(tournament) {
        if (tournament.current_phase === 'registration') {
            return this.playerRepo.find({
                where: {
                    tournament_id: tournament.id,
                    is_disqualified: false,
                },
                relations: ['user'],
                order: { seed: 'ASC' },
            });
        }
        const qualified = await this.playerRepo.find({
            where: {
                tournament_id: tournament.id,
                is_qualified: true,
                is_disqualified: false,
            },
            relations: ['user'],
            order: { seed: 'ASC' },
        });
        if (qualified.length > 0) {
            return qualified;
        }
        return this.playerRepo.find({
            where: {
                tournament_id: tournament.id,
                is_disqualified: false,
            },
            relations: ['user'],
            order: { seed: 'ASC' },
        });
    }
    nextPowerOfTwo(value) {
        let n = 1;
        while (n < value) {
            n *= 2;
        }
        return n;
    }
};
exports.TournamentsService = TournamentsService;
exports.TournamentsService = TournamentsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(tournament_entity_1.Tournament)),
    __param(1, (0, typeorm_1.InjectRepository)(tournament_player_entity_1.TournamentPlayer)),
    __param(2, (0, typeorm_1.InjectRepository)(tournament_pool_entity_1.TournamentPool)),
    __param(3, (0, typeorm_1.InjectRepository)(tournament_pool_standing_entity_1.TournamentPoolStanding)),
    __param(4, (0, typeorm_1.InjectRepository)(tournament_bracket_match_entity_1.TournamentBracketMatch)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], TournamentsService);
//# sourceMappingURL=tournaments.service.js.map