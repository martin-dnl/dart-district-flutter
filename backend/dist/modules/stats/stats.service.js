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
exports.StatsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const player_stat_entity_1 = require("./entities/player-stat.entity");
const elo_history_entity_1 = require("./entities/elo-history.entity");
const user_entity_1 = require("../users/entities/user.entity");
const normalize_limit_1 = require("../../common/utils/normalize-limit");
const throw_entity_1 = require("../matches/entities/throw.entity");
const match_entity_1 = require("../matches/entities/match.entity");
const club_member_entity_1 = require("../clubs/entities/club-member.entity");
const club_territory_points_entity_1 = require("../clubs/entities/club-territory-points.entity");
const territory_entity_1 = require("../territories/entities/territory.entity");
const K_FACTOR = 32;
let StatsService = class StatsService {
    constructor(statRepo, eloRepo, userRepo, throwRepo, matchRepo, clubMemberRepo, ctpRepo, territoryRepo) {
        this.statRepo = statRepo;
        this.eloRepo = eloRepo;
        this.userRepo = userRepo;
        this.throwRepo = throwRepo;
        this.matchRepo = matchRepo;
        this.clubMemberRepo = clubMemberRepo;
        this.ctpRepo = ctpRepo;
        this.territoryRepo = territoryRepo;
        this.territoryControlMinPoints = Math.max(1, Number(process.env.TERRITORY_CONTROL_MIN_POINTS ?? 200));
    }
    async getByUser(userId) {
        const stat = await this.statRepo.findOne({
            where: { user: { id: userId } },
        });
        if (!stat)
            throw new common_1.NotFoundException('Stats not found');
        return stat;
    }
    async updateAfterMatch(userId, matchData) {
        const stat = await this.statRepo.findOne({
            where: { user: { id: userId } },
        });
        if (!stat)
            return;
        const total = stat.matches_played + 1;
        stat.avg_score = ((stat.avg_score * stat.matches_played) + matchData.avg) / total;
        stat.best_avg = Math.max(stat.best_avg, matchData.avg);
        stat.matches_played = total;
        if (matchData.won)
            stat.matches_won += 1;
        if (matchData.highCheckout > stat.high_finish) {
            stat.high_finish = matchData.highCheckout;
        }
        if (matchData.bestLegDarts != null &&
            matchData.bestLegDarts > 0 &&
            (stat.best_leg_darts === 0 || matchData.bestLegDarts < stat.best_leg_darts)) {
            stat.best_leg_darts = matchData.bestLegDarts;
        }
        stat.total_180s += matchData.count180s;
        stat.count_140_plus += matchData.count140Plus;
        stat.count_100_plus += matchData.count100Plus;
        const endedAt = matchData.matchEndedAt ?? new Date();
        const endedDay = endedAt.toISOString().slice(0, 10);
        const lastPlayedDay = stat.last_played_date
            ? stat.last_played_date.toISOString().slice(0, 10)
            : null;
        if (lastPlayedDay !== endedDay) {
            const previousDay = new Date(endedAt);
            previousDay.setUTCDate(previousDay.getUTCDate() - 1);
            const previousDayLabel = previousDay.toISOString().slice(0, 10);
            if (lastPlayedDay === previousDayLabel) {
                stat.consecutive_days_played += 1;
            }
            else {
                stat.consecutive_days_played = 1;
            }
            stat.last_played_date = endedAt;
        }
        if (matchData.checkoutAttempts > 0) {
            const matchRate = (matchData.checkoutHits / matchData.checkoutAttempts) * 100;
            stat.checkout_rate = this.weightedRate(stat.checkout_rate, stat.matches_played - 1, matchRate);
        }
        if (matchData.t20Attempts > 0) {
            stat.precision_t20 = this.weightedRate(stat.precision_t20, stat.matches_played - 1, (matchData.t20Hits / matchData.t20Attempts) * 100);
        }
        if (matchData.t19Attempts > 0) {
            stat.precision_t19 = this.weightedRate(stat.precision_t19, stat.matches_played - 1, (matchData.t19Hits / matchData.t19Attempts) * 100);
        }
        if (matchData.doubleAttempts > 0) {
            stat.precision_double = this.weightedRate(stat.precision_double, stat.matches_played - 1, (matchData.doubleHits / matchData.doubleAttempts) * 100);
        }
        await this.statRepo.save(stat);
        return stat;
    }
    async processElo(matchId, winnerId, loserId, isRanked = true) {
        if (!isRanked) {
            return null;
        }
        const winner = await this.userRepo.findOne({ where: { id: winnerId } });
        const loser = await this.userRepo.findOne({ where: { id: loserId } });
        if (!winner || !loser)
            return;
        const expectedWinner = 1 / (1 + Math.pow(10, (loser.elo - winner.elo) / 400));
        const expectedLoser = 1 - expectedWinner;
        const deltaWinner = Math.round(K_FACTOR * (1 - expectedWinner));
        const deltaLoser = Math.round(K_FACTOR * (0 - expectedLoser));
        const winnerBefore = winner.elo;
        const loserBefore = loser.elo;
        winner.elo += deltaWinner;
        loser.elo += deltaLoser;
        await this.userRepo.save(winner);
        await this.userRepo.save(loser);
        await this.eloRepo.save(this.eloRepo.create({
            user_id: winner.id,
            match_id: matchId,
            elo_before: winnerBefore,
            elo_after: winner.elo,
            delta: deltaWinner,
        }));
        await this.eloRepo.save(this.eloRepo.create({
            user_id: loser.id,
            match_id: matchId,
            elo_before: loserBefore,
            elo_after: loser.elo,
            delta: deltaLoser,
        }));
        return { winner: { elo: winner.elo, delta: deltaWinner }, loser: { elo: loser.elo, delta: deltaLoser } };
    }
    async eloHistory(userId, limit = 30) {
        const take = (0, normalize_limit_1.normalizeLimit)(limit, 30);
        return this.eloRepo.find({
            where: { user: { id: userId } },
            order: { created_at: 'DESC' },
            take,
        });
    }
    async eloHistoryByPeriod(userId, mode = 'week', offset = 0) {
        const safeOffset = Math.max(0, Math.floor(offset));
        const now = new Date();
        const user = await this.userRepo.findOne({ where: { id: userId } });
        const fallbackElo = user?.elo ?? 1000;
        if (mode === 'year') {
            const anchorMonth = new Date(now.getFullYear(), now.getMonth() - safeOffset * 12, 1);
            const start = new Date(anchorMonth.getFullYear(), anchorMonth.getMonth() - 12, 1);
            const end = new Date(anchorMonth.getFullYear(), anchorMonth.getMonth() + 1, 0, 23, 59, 59, 999);
            const rows = await this.eloRepo
                .createQueryBuilder('e')
                .select(['e.elo_after', 'e.created_at'])
                .where('e.user_id = :userId', { userId })
                .andWhere('e.created_at <= :end', { end })
                .orderBy('e.created_at', 'ASC')
                .getMany();
            let cursor = 0;
            let currentElo = fallbackElo;
            const points = [];
            for (let i = 0; i <= 12; i++) {
                const monthStart = new Date(start.getFullYear(), start.getMonth() + i, 1);
                const monthEnd = new Date(monthStart.getFullYear(), monthStart.getMonth() + 1, 0, 23, 59, 59, 999);
                while (cursor < rows.length && rows[cursor].created_at <= monthEnd) {
                    currentElo = rows[cursor].elo_after;
                    cursor += 1;
                }
                points.push({
                    date: `${monthStart.getFullYear()}-${String(monthStart.getMonth() + 1).padStart(2, '0')}`,
                    elo: currentElo,
                });
            }
            const periodLabel = `${String(start.getMonth() + 1).padStart(2, '0')}/${start.getFullYear()} - ${String(anchorMonth.getMonth() + 1).padStart(2, '0')}/${anchorMonth.getFullYear()}`;
            return {
                mode,
                offset: safeOffset,
                period_label: periodLabel,
                points,
            };
        }
        const days = mode === 'week' ? 7 : 30;
        const anchor = new Date(now.getFullYear(), now.getMonth(), now.getDate() - safeOffset * days, 23, 59, 59, 999);
        const start = new Date(anchor.getFullYear(), anchor.getMonth(), anchor.getDate() - (days - 1), 0, 0, 0, 0);
        const rows = await this.eloRepo
            .createQueryBuilder('e')
            .select(['e.elo_after', 'e.created_at'])
            .where('e.user_id = :userId', { userId })
            .andWhere('e.created_at <= :anchor', { anchor })
            .orderBy('e.created_at', 'ASC')
            .getMany();
        let cursor = 0;
        let currentElo = fallbackElo;
        const points = [];
        for (let i = 0; i < days; i++) {
            const day = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            const dayEnd = new Date(day.getFullYear(), day.getMonth(), day.getDate(), 23, 59, 59, 999);
            while (cursor < rows.length && rows[cursor].created_at <= dayEnd) {
                currentElo = rows[cursor].elo_after;
                cursor += 1;
            }
            points.push({
                date: `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, '0')}-${String(day.getDate()).padStart(2, '0')}`,
                elo: currentElo,
            });
        }
        const periodLabel = `${String(start.getDate()).padStart(2, '0')}/${String(start.getMonth() + 1).padStart(2, '0')}/${start.getFullYear()} - ${String(anchor.getDate()).padStart(2, '0')}/${String(anchor.getMonth() + 1).padStart(2, '0')}/${anchor.getFullYear()}`;
        return {
            mode,
            offset: safeOffset,
            period_label: periodLabel,
            points,
        };
    }
    async processTerritoryPoints(params) {
        const match = await this.matchRepo.findOne({
            where: { id: params.matchId },
        });
        if (!match || !match.is_territorial || !match.territory_code_iris) {
            return null;
        }
        const winnerMembership = await this.clubMemberRepo.findOne({
            where: {
                user_id: params.winnerId,
                is_active: true,
            },
            relations: ['club'],
            order: { joined_at: 'ASC' },
        });
        const loserMembership = await this.clubMemberRepo.findOne({
            where: {
                user_id: params.loserId,
                is_active: true,
            },
            relations: ['club'],
            order: { joined_at: 'ASC' },
        });
        if (!winnerMembership) {
            return null;
        }
        if (loserMembership != null &&
            loserMembership.club?.id != null &&
            loserMembership.club.id === winnerMembership.club.id) {
            return null;
        }
        const winnerClubId = winnerMembership.club.id;
        const codeIris = match.territory_code_iris.toUpperCase();
        const pointsToAdd = Math.max(0, Math.floor(params.eloDelta ?? 0));
        if (pointsToAdd <= 0) {
            await this.recalculateTerritoryControl(codeIris);
            return null;
        }
        let association = await this.ctpRepo.findOne({
            where: {
                club_id: winnerClubId,
                code_iris: codeIris,
            },
        });
        if (!association) {
            association = this.ctpRepo.create({
                club_id: winnerClubId,
                code_iris: codeIris,
                points: 0,
            });
        }
        association.points += pointsToAdd;
        const saved = await this.ctpRepo.save(association);
        await this.userRepo
            .createQueryBuilder()
            .update(user_entity_1.User)
            .set({ conquest_score: () => `conquest_score + ${pointsToAdd}` })
            .where('id = :winnerId', { winnerId: params.winnerId })
            .execute();
        await this.recalculateTerritoryControl(codeIris);
        return saved;
    }
    async recalculateTerritoryControl(codeIris) {
        const territory = await this.territoryRepo.findOne({
            where: { code_iris: codeIris },
        });
        if (!territory) {
            return;
        }
        const rows = await this.ctpRepo.find({
            where: { code_iris: codeIris },
            order: { points: 'DESC' },
        });
        const eligible = rows.filter((row) => row.points >= this.territoryControlMinPoints);
        if (eligible.length === 0) {
            territory.owner_club_id = null;
            territory.status = 'available';
            territory.conquered_at = null;
            await this.territoryRepo.save(territory);
            return;
        }
        const leader = eligible[0];
        const second = eligible.length > 1 ? eligible[1] : null;
        const isTie = second != null && second.points === leader.points;
        if (isTie) {
            territory.status = 'conflict';
            await this.territoryRepo.save(territory);
            return;
        }
        const ownerChanged = territory.owner_club_id !== leader.club_id;
        territory.owner_club_id = leader.club_id;
        territory.status = 'conquered';
        if (ownerChanged) {
            territory.conquered_at = new Date();
        }
        await this.territoryRepo.save(territory);
    }
    async getDartboardPeriods(userId) {
        const rows = await this.throwRepo
            .createQueryBuilder('throw')
            .select("EXTRACT(YEAR FROM throw.created_at)", 'year')
            .addSelect("EXTRACT(MONTH FROM throw.created_at)", 'month')
            .where('throw.user_id = :userId', { userId })
            .andWhere('throw.dart_positions IS NOT NULL')
            .andWhere('jsonb_array_length(throw.dart_positions) > 0')
            .groupBy("EXTRACT(YEAR FROM throw.created_at)")
            .addGroupBy("EXTRACT(MONTH FROM throw.created_at)")
            .orderBy('year', 'DESC')
            .addOrderBy('month', 'ASC')
            .getRawMany();
        const grouped = new Map();
        for (const row of rows) {
            const year = Number(row.year);
            const month = Number(row.month);
            if (!Number.isFinite(year) || !Number.isFinite(month)) {
                continue;
            }
            const months = grouped.get(year) ?? [];
            if (!months.includes(month)) {
                months.push(month);
            }
            grouped.set(year, months);
        }
        return {
            years: Array.from(grouped.entries()).map(([year, months]) => ({
                year,
                months: [...months].sort((a, b) => a - b),
            })),
        };
    }
    async getDartboardHeatmap(userId, filter) {
        const period = this.normalizePeriod(filter.period);
        const query = this.throwRepo
            .createQueryBuilder('throw')
            .select(['throw.id', 'throw.score', 'throw.created_at', 'throw.dart_positions'])
            .where('throw.user_id = :userId', { userId })
            .andWhere('throw.dart_positions IS NOT NULL')
            .andWhere('jsonb_array_length(throw.dart_positions) > 0')
            .orderBy('throw.created_at', 'DESC');
        if (period == 'month') {
            const year = Number(filter.year);
            const month = Number(filter.month);
            if (!Number.isInteger(year) || !Number.isInteger(month) || month < 1 || month > 12) {
                throw new common_1.BadRequestException('Month period requires valid year and month');
            }
            query.andWhere("EXTRACT(YEAR FROM throw.created_at) = :year", { year });
            query.andWhere("EXTRACT(MONTH FROM throw.created_at) = :month", { month });
        }
        else if (period == 'year') {
            const year = Number(filter.year);
            if (!Number.isInteger(year)) {
                throw new common_1.BadRequestException('Year period requires a valid year');
            }
            query.andWhere("EXTRACT(YEAR FROM throw.created_at) = :year", { year });
        }
        const throws = await query.getMany();
        const hits = throws.flatMap((entry) => (entry.dart_positions ?? [])
            .filter((position) => position &&
            typeof position.x === 'number' &&
            typeof position.y === 'number')
            .map((position) => ({
            x: position.x,
            y: position.y,
            score: typeof position.score === 'number' ? position.score : entry.score,
            label: typeof position.label === 'string' ? position.label : undefined,
            played_at: entry.created_at,
        })));
        return {
            period,
            year: period == 'all' ? null : Number(filter.year ?? 0) || null,
            month: period == 'month' ? Number(filter.month ?? 0) || null : null,
            total_throws: throws.length,
            total_hits: hits.length,
            hits,
        };
    }
    normalizePeriod(period) {
        switch ((period ?? 'all').toLowerCase()) {
            case 'month':
                return 'month';
            case 'year':
                return 'year';
            case 'all':
            default:
                return 'all';
        }
    }
    weightedRate(currentRate, totalGames, newRate) {
        return ((currentRate * totalGames) + newRate) / (totalGames + 1);
    }
};
exports.StatsService = StatsService;
exports.StatsService = StatsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(player_stat_entity_1.PlayerStat)),
    __param(1, (0, typeorm_1.InjectRepository)(elo_history_entity_1.EloHistory)),
    __param(2, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __param(3, (0, typeorm_1.InjectRepository)(throw_entity_1.Throw)),
    __param(4, (0, typeorm_1.InjectRepository)(match_entity_1.Match)),
    __param(5, (0, typeorm_1.InjectRepository)(club_member_entity_1.ClubMember)),
    __param(6, (0, typeorm_1.InjectRepository)(club_territory_points_entity_1.ClubTerritoryPoints)),
    __param(7, (0, typeorm_1.InjectRepository)(territory_entity_1.Territory)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], StatsService);
//# sourceMappingURL=stats.service.js.map