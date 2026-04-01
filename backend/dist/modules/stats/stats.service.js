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
const K_FACTOR = 32;
let StatsService = class StatsService {
    constructor(statRepo, eloRepo, userRepo) {
        this.statRepo = statRepo;
        this.eloRepo = eloRepo;
        this.userRepo = userRepo;
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
        stat.total_180s += matchData.count180s;
        stat.count_140_plus += matchData.count140Plus;
        stat.count_100_plus += matchData.count100Plus;
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
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], StatsService);
//# sourceMappingURL=stats.service.js.map