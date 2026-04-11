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
exports.MatchesService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const match_entity_1 = require("./entities/match.entity");
const match_player_entity_1 = require("./entities/match-player.entity");
const set_entity_1 = require("./entities/set.entity");
const leg_entity_1 = require("./entities/leg.entity");
const throw_entity_1 = require("./entities/throw.entity");
const system_gateway_1 = require("../realtime/gateways/system.gateway");
const match_gateway_1 = require("../realtime/gateways/match.gateway");
const normalize_limit_1 = require("../../common/utils/normalize-limit");
const stats_service_1 = require("../stats/stats.service");
const territory_entity_1 = require("../territories/entities/territory.entity");
let MatchesService = class MatchesService {
    constructor(matchRepo, playerRepo, setRepo, legRepo, throwRepo, territoryRepo, dataSource, systemGateway, matchGateway, statsService) {
        this.matchRepo = matchRepo;
        this.playerRepo = playerRepo;
        this.setRepo = setRepo;
        this.legRepo = legRepo;
        this.throwRepo = throwRepo;
        this.territoryRepo = territoryRepo;
        this.dataSource = dataSource;
        this.systemGateway = systemGateway;
        this.matchGateway = matchGateway;
        this.statsService = statsService;
    }
    async createInvitation(inviterId, body) {
        if (!body.invitee_id) {
            throw new common_1.BadRequestException('invitee_id is required');
        }
        if (body.invitee_id === inviterId) {
            throw new common_1.BadRequestException('Cannot invite yourself');
        }
        const mode = this.normalizeMode(body.mode);
        const startingScore = body.starting_score ?? this.resolveStartingScore(mode);
        const setsToWin = Math.max(1, body.sets_to_win ?? 1);
        const legsPerSet = Math.max(1, body.legs_per_set ?? 3);
        const finishType = this.normalizeFinishType(body.finish_type);
        const queryRunner = this.dataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();
        try {
            const match = queryRunner.manager.create(match_entity_1.Match, {
                mode,
                finish: finishType,
                total_sets: setsToWin,
                legs_per_set: legsPerSet,
                is_ranked: body.is_ranked ?? false,
                is_territorial: body.is_territorial ?? false,
                territory_club_id: body.territory_club_id ?? null,
                territory_code_iris: body.territory_code_iris ?? null,
                status: 'pending',
                inviter_id: inviterId,
                invitee_id: body.invitee_id,
                invitation_status: 'pending',
                invitation_created_at: new Date(),
            });
            await queryRunner.manager.save(match);
            const home = queryRunner.manager.create(match_player_entity_1.MatchPlayer, {
                match,
                user: { id: inviterId },
                side: 'home',
            });
            const away = queryRunner.manager.create(match_player_entity_1.MatchPlayer, {
                match,
                user: { id: body.invitee_id },
                side: 'away',
            });
            await queryRunner.manager.save([home, away]);
            const firstSet = queryRunner.manager.create(set_entity_1.Set, {
                match,
                set_number: 1,
            });
            await queryRunner.manager.save(firstSet);
            const firstLeg = queryRunner.manager.create(leg_entity_1.Leg, {
                set: firstSet,
                leg_number: 1,
                starting_score: startingScore,
            });
            await queryRunner.manager.save(firstLeg);
            await queryRunner.commitTransaction();
            const serialized = await this.loadSerializedMatch(match.id);
            this.systemGateway.emitUserEvent(body.invitee_id, 'match_invitation', serialized);
            return serialized;
        }
        catch (err) {
            await queryRunner.rollbackTransaction();
            throw err;
        }
        finally {
            await queryRunner.release();
        }
    }
    async getOngoingForUser(userId) {
        const matches = await this.matchRepo
            .createQueryBuilder('m')
            .innerJoin('m.players', 'mp', 'mp.user_id = :userId', { userId })
            .where('m.status = :inProgress', {
            inProgress: 'in_progress',
        })
            .orWhere(new typeorm_2.Brackets((qb) => {
            qb.where('m.status = :pending', { pending: 'pending' }).andWhere('m.invitation_status = :invitationPending', { invitationPending: 'pending' });
        }))
            .andWhere('m.status != :cancelled', {
            cancelled: 'cancelled',
        })
            .orderBy('m.created_at', 'DESC')
            .getMany();
        return Promise.all(matches.map((m) => this.loadSerializedMatch(m.id)));
    }
    async acceptInvitation(matchId, userId) {
        const match = await this.loadMatchWithGraph(matchId);
        if (!match.invitee_id || match.invitee_id !== userId) {
            throw new common_1.BadRequestException('Only invitee can accept invitation');
        }
        if (match.invitation_status !== 'pending') {
            throw new common_1.BadRequestException('Invitation is no longer pending');
        }
        match.invitation_status = 'accepted';
        match.status = 'in_progress';
        match.started_at = new Date();
        await this.matchRepo.save(match);
        const serialized = await this.loadSerializedMatch(match.id);
        if (match.inviter_id) {
            this.systemGateway.emitUserEvent(match.inviter_id, 'match_invitation_accepted', serialized);
        }
        this.systemGateway.emitUserEvent(userId, 'match_invitation_accepted', serialized);
        return serialized;
    }
    async refuseInvitation(matchId, userId) {
        const match = await this.loadMatchWithGraph(matchId);
        if (!match.invitee_id || match.invitee_id !== userId) {
            throw new common_1.BadRequestException('Only invitee can refuse invitation');
        }
        if (match.invitation_status !== 'pending') {
            throw new common_1.BadRequestException('Invitation is no longer pending');
        }
        match.invitation_status = 'refused';
        match.status = 'cancelled';
        match.ended_at = new Date();
        const serialized = this.serializeMatch(match);
        await this.matchRepo.delete(match.id);
        if (match.inviter_id) {
            this.systemGateway.emitUserEvent(match.inviter_id, 'match_invitation_refused', serialized);
        }
        return { ok: true };
    }
    async cancelInvitation(matchId, userId) {
        const match = await this.loadMatchWithGraph(matchId);
        if (!match.inviter_id || match.inviter_id !== userId) {
            throw new common_1.BadRequestException('Only inviter can cancel invitation');
        }
        if (match.invitation_status !== 'pending') {
            throw new common_1.BadRequestException('Invitation is no longer pending');
        }
        match.invitation_status = 'refused';
        match.status = 'cancelled';
        match.ended_at = new Date();
        const serialized = this.serializeMatch(match);
        await this.matchRepo.delete(match.id);
        if (match.invitee_id) {
            this.systemGateway.emitUserEvent(match.invitee_id, 'match_invitation_refused', serialized);
        }
        return { ok: true };
    }
    async submitScore(matchId, userId, body) {
        const score = Math.max(0, Math.floor(body.score ?? 0));
        const match = await this.loadMatchWithGraph(matchId);
        if (match.status !== 'in_progress') {
            throw new common_1.BadRequestException('Match is not in progress');
        }
        const players = this.getOrderedPlayers(match);
        if (players.findIndex((p) => p.user_id === userId) < 0) {
            throw new common_1.BadRequestException('You are not a player in this match');
        }
        const { leg: activeLeg } = this.getActiveSetAndLeg(match);
        const expectedPlayerIndex = this.computeCurrentPlayerIndex(match, activeLeg, players.length);
        const targetPlayer = players[expectedPlayerIndex];
        const playerThrows = (activeLeg.throws ?? []).filter((t) => t.user_id === targetPlayer.user_id);
        const thrownTotal = playerThrows.reduce((sum, t) => sum + t.score, 0);
        const remaining = activeLeg.starting_score - thrownTotal - score;
        const roundNumber = Math.floor((activeLeg.throws?.length ?? 0) / Math.max(players.length, 1)) +
            1;
        const isDoubleOut = match.finish === 'double_out';
        const isMasterOut = match.finish === 'master_out';
        const bustOnOneRemaining = (isDoubleOut || isMasterOut) && remaining === 1;
        const isBust = remaining < 0 || bustOnOneRemaining;
        const isCheckout = remaining == 0 && !isBust;
        let segment = `VISIT_${score}`;
        let recordedScore = score;
        let recordedRemaining = remaining;
        let doublesAttempted = 0;
        if (isBust) {
            segment = 'BUST';
            recordedScore = 0;
            recordedRemaining = activeLeg.starting_score - thrownTotal;
        }
        if (isCheckout && (isDoubleOut || isMasterOut)) {
            doublesAttempted = body.doubles_attempted ?? 0;
            if (doublesAttempted < 1 || doublesAttempted > 3) {
                throw new common_1.BadRequestException('doubles_attempted must be between 1 and 3 for checkout');
            }
            segment = `CD${doublesAttempted}`;
        }
        const dartPositions = (body.dart_positions ?? [])
            .slice(0, 3)
            .map((p) => ({
            x: Math.min(1, Math.max(0, Number(p.x))),
            y: Math.min(1, Math.max(0, Number(p.y))),
            ...(typeof p.score === 'number' ? { score: Math.floor(p.score) } : {}),
            ...(typeof p.label === 'string' ? { label: p.label.slice(0, 16) } : {}),
        }))
            .filter((p) => Number.isFinite(p.x) && Number.isFinite(p.y));
        const savedThrow = this.throwRepo.create({
            leg: activeLeg,
            user: { id: targetPlayer.user_id },
            leg_id: activeLeg.id,
            user_id: targetPlayer.user_id,
            round_num: roundNumber,
            dart_num: 1,
            segment: `VISIT_${score}`,
            score: recordedScore,
            remaining: recordedRemaining,
            dart_positions: dartPositions.length > 0 ? dartPositions : undefined,
            is_checkout: isCheckout,
        });
        savedThrow.segment = segment;
        await this.throwRepo.save(savedThrow);
        if (isCheckout) {
            await this.completeLeg(activeLeg, targetPlayer.user_id);
        }
        const serialized = await this.loadSerializedMatch(matchId);
        const userIds = players.map((p) => p.user_id).filter(Boolean);
        for (const id of userIds) {
            this.systemGateway.emitUserEvent(id, 'match_score_update', serialized);
        }
        this.matchGateway.emitMatchUpdate(matchId, serialized);
        return serialized;
    }
    async undoLastThrow(matchId, userId) {
        const match = await this.loadMatchWithGraph(matchId);
        if (match.status !== 'in_progress') {
            throw new common_1.BadRequestException('Match is not in progress');
        }
        const players = this.getOrderedPlayers(match);
        if (!players.some((p) => p.user_id === userId)) {
            throw new common_1.BadRequestException('You are not a player in this match');
        }
        const { leg: activeLeg } = this.getActiveSetAndLeg(match);
        const latestThrow = [...(activeLeg.throws ?? [])].sort((a, b) => b.created_at.getTime() - a.created_at.getTime())[0];
        if (!latestThrow) {
            throw new common_1.BadRequestException('No throw to undo');
        }
        await this.throwRepo.delete(latestThrow.id);
        const serialized = await this.loadSerializedMatch(matchId);
        const userIds = players.map((p) => p.user_id).filter(Boolean);
        for (const id of userIds) {
            this.systemGateway.emitUserEvent(id, 'match_score_update', serialized);
        }
        this.matchGateway.emitMatchUpdate(matchId, serialized);
        return serialized;
    }
    async abandonMatch(matchId, userId, body) {
        const match = await this.loadMatchWithGraph(matchId);
        if (match.status !== 'in_progress') {
            throw new common_1.BadRequestException('Match is not in progress');
        }
        const players = this.getOrderedPlayers(match);
        const requesterIsPlayer = players.some((p) => p.user_id === userId);
        if (!requesterIsPlayer) {
            throw new common_1.BadRequestException('You are not a player in this match');
        }
        const surrenderedByIndex = Math.floor(body.surrendered_by_index ?? -1);
        if (surrenderedByIndex < 0 || surrenderedByIndex >= players.length) {
            throw new common_1.BadRequestException('Invalid surrendered_by_index');
        }
        const surrenderedPlayer = players[surrenderedByIndex];
        match.surrendered_by = surrenderedPlayer.user_id;
        match.status = 'completed';
        match.ended_at = new Date();
        await this.matchRepo.save(match);
        for (const mp of match.players ?? []) {
            mp.is_winner = mp.user_id !== surrenderedPlayer.user_id;
        }
        await this.playerRepo.save(match.players ?? []);
        const serialized = await this.loadSerializedMatch(matchId);
        const userIds = players.map((p) => p.user_id).filter(Boolean);
        for (const id of userIds) {
            this.systemGateway.emitUserEvent(id, 'match_score_update', serialized);
        }
        this.matchGateway.emitMatchUpdate(matchId, serialized);
        return serialized;
    }
    async create(dto) {
        const queryRunner = this.dataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();
        try {
            const match = queryRunner.manager.create(match_entity_1.Match, {
                mode: dto.mode,
                finish: dto.finish_type === 'straight_out' ? 'single_out' : dto.finish_type,
                total_sets: dto.best_of_sets,
                legs_per_set: dto.best_of_legs,
                is_territorial: dto.is_territorial ?? false,
                is_ranked: dto.is_ranked ?? false,
                territory_id: dto.territory_id ?? null,
                territory_club_id: dto.club_id ?? null,
                territory_code_iris: dto.territory_id ?? null,
                tournament_id: dto.tournament_id ?? null,
                status: 'in_progress',
                started_at: new Date(),
            });
            await queryRunner.manager.save(match);
            const sides = ['home', 'away'];
            for (let i = 0; i < dto.player_ids.length; i++) {
                const mp = queryRunner.manager.create(match_player_entity_1.MatchPlayer, {
                    match,
                    user: { id: dto.player_ids[i] },
                    side: sides[i] ?? 'home',
                    final_score: 0,
                });
                await queryRunner.manager.save(mp);
            }
            const set = queryRunner.manager.create(set_entity_1.Set, { match, set_number: 1 });
            await queryRunner.manager.save(set);
            const startingScore = dto.mode === '301' ? 301 : 501;
            const leg = queryRunner.manager.create(leg_entity_1.Leg, {
                set,
                leg_number: 1,
                starting_score: startingScore,
            });
            await queryRunner.manager.save(leg);
            await queryRunner.commitTransaction();
            return this.findById(match.id);
        }
        catch (err) {
            await queryRunner.rollbackTransaction();
            throw err;
        }
        finally {
            await queryRunner.release();
        }
    }
    async findById(id) {
        const match = await this.matchRepo.findOne({
            where: { id },
            relations: [
                'players',
                'players.user',
                'sets',
                'sets.legs',
                'sets.legs.throws',
            ],
        });
        if (!match)
            throw new common_1.NotFoundException('Match not found');
        return match;
    }
    async findByUser(userId, limit = 20, offset = 0, status, ranked) {
        const take = (0, normalize_limit_1.normalizeLimit)(limit, 20);
        const skip = Math.max(0, Math.floor(offset || 0));
        const qb = this.matchRepo
            .createQueryBuilder('m')
            .innerJoin('m.players', 'mp', 'mp.user_id = :userId', { userId })
            .leftJoinAndSelect('m.players', 'allPlayers')
            .leftJoinAndSelect('allPlayers.user', 'u')
            .leftJoinAndSelect('m.sets', 's')
            .orderBy('m.created_at', 'DESC')
            .skip(skip)
            .take(take);
        if (status) {
            qb.andWhere('m.status = :status', { status });
        }
        if ((ranked ?? '').toLowerCase() === 'true') {
            qb.andWhere('m.is_ranked = :isRanked', { isRanked: true });
        }
        const matches = await qb.getMany();
        return matches.map((m) => {
            const orderedPlayers = this.getOrderedPlayers(m);
            const winnerId = orderedPlayers.find((p) => p.is_winner)?.user_id ?? null;
            return {
                id: m.id,
                mode: m.mode,
                status: this.toClientStatus(m.status),
                is_ranked: m.is_ranked,
                created_at: m.created_at,
                started_at: m.started_at,
                completed_at: m.ended_at,
                surrendered_by: m.surrendered_by,
                winner_id: winnerId,
                players: orderedPlayers.map((p) => ({
                    user_id: p.user_id,
                    username: p.user?.username ?? 'Joueur',
                    avatar_url: p.user?.avatar_url ?? null,
                    is_winner: p.is_winner,
                    sets_won: (m.sets ?? []).filter((s) => s.winner_id === p.user_id).length,
                })),
            };
        });
    }
    async getMatchReport(matchId) {
        const match = await this.matchRepo.findOne({
            where: { id: matchId },
            relations: [
                'players',
                'players.user',
                'sets',
                'sets.legs',
                'sets.legs.throws',
            ],
        });
        if (!match) {
            throw new common_1.NotFoundException('Match not found');
        }
        const orderedPlayers = this.getOrderedPlayers(match);
        const allLegs = (match.sets ?? []).flatMap((s) => s.legs ?? []);
        const allThrows = allLegs.flatMap((l) => l.throws ?? []);
        const finalSets = orderedPlayers.map((p) => (match.sets ?? []).filter((s) => s.winner_id === p.user_id).length);
        const players = orderedPlayers.map((p) => {
            const throwsForPlayer = allThrows.filter((t) => t.user_id === p.user_id);
            const totalScore = throwsForPlayer.reduce((sum, t) => sum + t.score, 0);
            const legsWon = allLegs.filter((l) => l.winner_id === p.user_id).length;
            const count180 = throwsForPlayer.filter((t) => t.score === 180).length;
            const count140Plus = throwsForPlayer.filter((t) => t.score >= 140).length;
            const count100Plus = throwsForPlayer.filter((t) => t.score >= 100).length;
            const checkoutAttempts = throwsForPlayer
                .map((t) => this.extractDoubleAttemptsFromSegment(t.segment))
                .reduce((sum, attempts) => sum + attempts, 0);
            const checkoutHits = throwsForPlayer.filter((t) => t.is_checkout).length;
            const highestCheckout = throwsForPlayer
                .filter((t) => t.is_checkout)
                .reduce((max, t) => Math.max(max, t.score), 0);
            return {
                user_id: p.user_id,
                username: p.user?.username ?? 'Unknown',
                avatar_url: p.user?.avatar_url ?? null,
                avg_score: throwsForPlayer.length > 0
                    ? Number((totalScore / throwsForPlayer.length).toFixed(2))
                    : 0,
                legs_won: legsWon,
                count_180: count180,
                count_140_plus: count140Plus,
                count_100_plus: count100Plus,
                checkout_rate: checkoutAttempts > 0
                    ? Number(((checkoutHits / checkoutAttempts) * 100).toFixed(2))
                    : 0,
                checkout_attempts: checkoutAttempts,
                checkout_hits: checkoutHits,
                highest_checkout: highestCheckout,
                total_darts: throwsForPlayer.length * 3,
                dart_positions: throwsForPlayer.flatMap((t) => (t.dart_positions ?? [])
                    .filter((position) => position &&
                    typeof position.x === 'number' &&
                    typeof position.y === 'number')
                    .map((position) => ({
                    x: position.x,
                    y: position.y,
                    score: typeof position.score === 'number' ? position.score : undefined,
                    label: typeof position.label === 'string' ? position.label : undefined,
                }))),
            };
        });
        const usernameById = new Map(orderedPlayers.map((p) => [p.user_id, p.user?.username ?? 'Unknown']));
        const timeline = (match.sets ?? [])
            .sort((a, b) => a.set_number - b.set_number)
            .flatMap((set) => (set.legs ?? [])
            .sort((a, b) => a.leg_number - b.leg_number)
            .filter((leg) => !!leg.winner_id)
            .map((leg) => ({
            set: set.set_number,
            leg: leg.leg_number,
            winner_username: usernameById.get(leg.winner_id ?? '') ?? 'Unknown',
        })));
        return {
            match_id: match.id,
            mode: match.mode,
            final_sets: finalSets,
            players,
            timeline,
        };
    }
    async getResultSummary(matchId, userId) {
        const match = await this.loadMatchWithGraph(matchId);
        const orderedPlayers = this.getOrderedPlayers(match);
        const me = orderedPlayers.find((player) => player.user_id === userId);
        if (!me) {
            throw new common_1.BadRequestException('You are not a player in this match');
        }
        const eloRow = await this.dataSource.query(`
        SELECT elo_before, elo_after, delta
        FROM elo_history
        WHERE match_id = $1 AND user_id = $2
        ORDER BY created_at DESC
        LIMIT 1
      `, [matchId, userId]);
        const winner = orderedPlayers.find((player) => player.is_winner);
        const isWinner = winner?.user_id === userId;
        const eloBefore = Number(eloRow?.[0]?.elo_before ?? 0);
        const eloAfter = Number(eloRow?.[0]?.elo_after ?? 0);
        const eloDelta = Number(eloRow?.[0]?.delta ?? 0);
        let territoryName = null;
        if (match.territory_code_iris) {
            const territory = await this.territoryRepo.findOne({
                where: { code_iris: match.territory_code_iris.toUpperCase() },
            });
            territoryName = territory?.name ?? null;
        }
        const territoryPointsGained = match.is_ranked && match.is_territorial && isWinner
            ? Math.max(0, Math.abs(eloDelta))
            : 0;
        return {
            match_id: match.id,
            is_ranked: match.is_ranked,
            is_territorial: match.is_territorial,
            user_id: userId,
            is_winner: isWinner,
            elo_before: eloBefore,
            elo_after: eloAfter,
            elo_delta: eloDelta,
            territory_points_gained: territoryPointsGained,
            territory_code_iris: match.territory_code_iris ?? null,
            territory_name: territoryName,
        };
    }
    async submitThrow(matchId, legId, playerId, dto) {
        const leg = await this.legRepo.findOne({
            where: { id: legId },
            relations: ['set', 'set.match'],
        });
        if (!leg)
            throw new common_1.NotFoundException('Leg not found');
        if (leg.set.match.id !== matchId)
            throw new common_1.BadRequestException('Leg does not belong to match');
        const existingThrows = await this.throwRepo.find({
            where: { leg: { id: legId }, user: { id: playerId } },
        });
        const thrownTotal = existingThrows.reduce((s, t) => s + t.score, 0);
        const remaining = leg.starting_score - thrownTotal - dto.score;
        if (remaining < 0)
            throw new common_1.BadRequestException('Score exceeds remaining');
        const t = this.throwRepo.create({
            leg,
            user: { id: playerId },
            leg_id: leg.id,
            user_id: playerId,
            round_num: dto.round_number,
            dart_num: dto.dart_number,
            segment: dto.segment,
            score: dto.score,
            remaining,
            is_checkout: remaining === 0,
        });
        await this.throwRepo.save(t);
        if (remaining === 0) {
            await this.completeLeg(leg, playerId);
        }
        return t;
    }
    async completeLeg(leg, winnerId) {
        await this.legRepo.update({ id: leg.id }, { winner_id: winnerId });
        const setId = leg.set_id ?? leg.set?.id;
        if (!setId) {
            return;
        }
        const set = await this.setRepo.findOne({
            where: { id: setId },
            relations: ['match', 'legs'],
        });
        if (!set)
            return;
        const match = await this.findById(set.match.id);
        const legsToWin = this.isInvitationFlow(match)
            ? match.legs_per_set
            : Math.ceil(match.legs_per_set / 2);
        const legsWon = set.legs.filter((l) => l.winner_id === winnerId).length;
        if (legsWon >= legsToWin) {
            await this.setRepo.update({ id: set.id }, { winner_id: winnerId });
            const freshMatch = await this.findById(match.id);
            await this.checkMatchCompletion(freshMatch, winnerId);
        }
        else {
            const newLeg = this.legRepo.create({
                set,
                leg_number: set.legs.length + 1,
                starting_score: this.resolveStartingScore(match.mode),
            });
            await this.legRepo.save(newLeg);
        }
    }
    async checkMatchCompletion(match, lastSetWinnerId) {
        const setsToWin = this.isInvitationFlow(match)
            ? match.total_sets
            : Math.ceil(match.total_sets / 2);
        const setsWon = match.sets.filter((s) => s.winner_id === lastSetWinnerId).length;
        if (setsWon >= setsToWin) {
            match.status = 'completed';
            match.ended_at = new Date();
            await this.matchRepo.save(match);
            const loserId = match.players.find((p) => p.user.id !== lastSetWinnerId)?.user
                .id;
            for (const mp of match.players) {
                mp.is_winner = mp.user.id === lastSetWinnerId;
                await this.playerRepo.save(mp);
            }
            if (loserId) {
                const eloResult = await this.statsService.processElo(match.id, lastSetWinnerId, loserId, match.is_ranked);
                if (match.is_territorial) {
                    await this.statsService.processTerritoryPoints({
                        matchId: match.id,
                        winnerId: lastSetWinnerId,
                        loserId,
                        eloDelta: Math.abs(eloResult?.winner.delta ?? 0),
                    });
                }
            }
            if (match.is_ranked) {
                for (const mp of match.players) {
                    const playerId = mp.user.id;
                    const matchData = this.buildPlayerMatchStats(match, playerId);
                    await this.statsService.updateAfterMatch(playerId, {
                        ...matchData,
                        won: mp.is_winner === true,
                        matchEndedAt: match.ended_at ?? new Date(),
                    });
                }
            }
        }
        else {
            const newSet = this.setRepo.create({
                match,
                set_number: match.sets.length + 1,
            });
            await this.setRepo.save(newSet);
            const newLeg = this.legRepo.create({
                set: newSet,
                leg_number: 1,
                starting_score: this.resolveStartingScore(match.mode),
            });
            await this.legRepo.save(newLeg);
        }
    }
    async validateMatch(matchId, userId) {
        const match = await this.findById(matchId);
        const player = match.players.find((p) => p.user.id === userId);
        if (!player)
            throw new common_1.BadRequestException('Not a player in this match');
        if (player.side === 'home') {
            match.validated_by_home = true;
        }
        else {
            match.validated_by_away = true;
        }
        if (match.validated_by_home && match.validated_by_away) {
            match.status = 'awaiting_validation';
        }
        return this.matchRepo.save(match);
    }
    async loadMatchWithGraph(id) {
        const match = await this.matchRepo.findOne({
            where: { id },
            relations: [
                'players',
                'players.user',
                'sets',
                'sets.legs',
                'sets.legs.throws',
            ],
        });
        if (!match) {
            throw new common_1.NotFoundException('Match not found');
        }
        return match;
    }
    async loadSerializedMatch(id) {
        const match = await this.loadMatchWithGraph(id);
        return this.serializeMatch(match);
    }
    serializeMatch(match) {
        const players = this.getOrderedPlayers(match);
        const playerCount = Math.max(1, players.length);
        const { set: activeSet, leg: activeLeg } = this.getActiveSetAndLeg(match);
        const startingScore = activeLeg?.starting_score ?? this.resolveStartingScore(match.mode);
        const legThrows = [...(activeLeg?.throws ?? [])].sort((a, b) => {
            if (a.round_num !== b.round_num)
                return a.round_num - b.round_num;
            if (a.dart_num !== b.dart_num)
                return a.dart_num - b.dart_num;
            return a.created_at.getTime() - b.created_at.getTime();
        });
        const allThrows = [...(match.sets ?? [])]
            .flatMap((s) => s.legs ?? [])
            .flatMap((l) => l.throws ?? [])
            .sort((a, b) => a.created_at.getTime() - b.created_at.getTime());
        const serializedPlayers = players.map((player) => {
            const throwScores = legThrows
                .filter((t) => t.user_id === player.user_id && t.segment !== 'BUST')
                .map((t) => t.score);
            const thrown = throwScores.reduce((sum, value) => sum + value, 0);
            const score = Math.max(0, startingScore - thrown);
            const legsWon = (activeSet?.legs ?? []).filter((l) => l.winner_id === player.user_id).length;
            const setsWon = (match.sets ?? []).filter((s) => s.winner_id === player.user_id).length;
            const average = throwScores.length === 0
                ? 0
                : throwScores.reduce((sum, value) => sum + value, 0) /
                    throwScores.length;
            const playerAllThrows = allThrows.filter((t) => t.user_id === player.user_id);
            const finalDoubleAttempts = playerAllThrows
                .map((t) => this.extractDoubleAttemptsFromSegment(t.segment))
                .reduce((sum, attempts) => sum + attempts, 0);
            const finalDoubleHits = playerAllThrows.filter((t) => t.is_checkout).length;
            return {
                user_id: player.user_id,
                name: player.user?.username ?? 'Joueur',
                score,
                legs_won: legsWon,
                sets_won: setsWon,
                throw_scores: throwScores,
                average,
                doubles_attempted: finalDoubleAttempts,
                doubles_hit: finalDoubleHits,
            };
        });
        const completedLegs = this.countCompletedLegs(match);
        const starterIndex = completedLegs % playerCount;
        const currentPlayerIndex = match.status === 'in_progress'
            ? this.computeCurrentPlayerIndex(match, activeLeg, playerCount)
            : starterIndex;
        const abandonedByIndex = players.findIndex((p) => p.user_id === match.surrendered_by);
        const roundHistory = allThrows.map((t) => {
            const finalPlayerIndex = players.findIndex((p) => p.user_id === t.user_id);
            return {
                'player_index': finalPlayerIndex < 0 ? 0 : finalPlayerIndex,
                'round': t.round_num,
                'darts': [t.score],
                'total': t.score,
                'is_bust': t.segment == 'BUST',
                'doubles_attempted': this.extractDoubleAttemptsFromSegment(t.segment),
                'dart_positions': t.dart_positions ?? [],
            };
        });
        return {
            'id': match.id,
            'mode': match.mode,
            'starting_score': startingScore,
            'players': serializedPlayers,
            'starting_player_index': starterIndex,
            'current_player_index': currentPlayerIndex,
            'current_round': legThrows.length === 0
                ? 1
                : (Math.floor(legThrows.length / playerCount) + 1),
            'current_leg': activeLeg?.leg_number ?? 1,
            'current_set': activeSet?.set_number ?? 1,
            'status': this.toClientStatus(match.status),
            'round_history': roundHistory,
            'inviter_id': match.inviter_id,
            'invitee_id': match.invitee_id,
            'invitation_status': match.invitation_status,
            'invitation_created_at': match.invitation_created_at,
            'sets_to_win': match.total_sets,
            'legs_per_set': match.legs_per_set,
            'finish_type': match.finish,
            'is_ranked': match.is_ranked,
            'is_territorial': match.is_territorial,
            'territory_club_id': match.territory_club_id,
            'territory_code_iris': match.territory_code_iris,
            'abandoned_by_index': abandonedByIndex < 0 ? null : abandonedByIndex,
        };
    }
    getOrderedPlayers(match) {
        return [...(match.players ?? [])].sort((a, b) => {
            const rank = (side) => (side === 'home' ? 0 : 1);
            return rank(a.side) - rank(b.side);
        });
    }
    getActiveSetAndLeg(match) {
        const sets = [...(match.sets ?? [])].sort((a, b) => a.set_number - b.set_number);
        const activeSet = sets.find((s) => !s.winner_id) ?? sets[sets.length - 1];
        const legs = [...(activeSet?.legs ?? [])].sort((a, b) => a.leg_number - b.leg_number);
        const activeLeg = legs.find((l) => !l.winner_id) ?? legs[legs.length - 1];
        if (!activeSet || !activeLeg) {
            throw new common_1.BadRequestException('Match has no active set/leg');
        }
        return { set: activeSet, leg: activeLeg };
    }
    normalizeMode(raw) {
        const normalized = (raw ?? '501').toLowerCase();
        switch (normalized) {
            case '301':
                return '301';
            case '501':
                return '501';
            case '701':
                return '701';
            case 'cricket':
                return 'cricket';
            case 'chasseur':
                return 'chasseur';
            default:
                return '501';
        }
    }
    normalizeFinishType(raw) {
        switch ((raw ?? '').toLowerCase()) {
            case 'single_out':
            case 'straight_out':
                return 'single_out';
            case 'master_out':
                return 'master_out';
            default:
                return 'double_out';
        }
    }
    resolveStartingScore(mode) {
        if (mode === '301')
            return 301;
        if (mode === '701')
            return 701;
        return 501;
    }
    toClientStatus(status) {
        switch (status) {
            case 'pending':
                return 'waiting';
            case 'completed':
            case 'cancelled':
                return 'finished';
            default:
                return 'in_progress';
        }
    }
    isInvitationFlow(match) {
        return Boolean(match.inviter_id && match.invitee_id);
    }
    extractDoubleAttemptsFromSegment(segment) {
        if (segment.startsWith('CD')) {
            return Number.parseInt(segment.slice(2), 10) || 0;
        }
        if (segment.startsWith('CHECKOUT_D')) {
            return Number.parseInt(segment.replace('CHECKOUT_D', ''), 10) || 0;
        }
        return 0;
    }
    countCompletedLegs(match) {
        return (match.sets ?? [])
            .flatMap((s) => s.legs ?? [])
            .filter((l) => l.winner_id != null).length;
    }
    buildPlayerMatchStats(match, userId) {
        const allLegs = (match.sets ?? []).flatMap((s) => s.legs ?? []);
        const throwsForPlayer = allLegs
            .flatMap((leg) => leg.throws ?? [])
            .filter((t) => t.user_id === userId);
        const totalScore = throwsForPlayer.reduce((sum, t) => sum + t.score, 0);
        const avg = throwsForPlayer.length > 0
            ? Number((totalScore / throwsForPlayer.length).toFixed(2))
            : 0;
        const highCheckout = throwsForPlayer
            .filter((t) => t.is_checkout)
            .reduce((max, t) => Math.max(max, t.score), 0);
        const count180s = throwsForPlayer.filter((t) => t.score === 180).length;
        const count140Plus = throwsForPlayer.filter((t) => t.score >= 140).length;
        const count100Plus = throwsForPlayer.filter((t) => t.score >= 100).length;
        const checkoutAttempts = throwsForPlayer.reduce((sum, t) => {
            const encoded = this.extractDoubleAttemptsFromSegment(t.segment);
            if (encoded > 0) {
                return sum + encoded;
            }
            if (t.is_checkout) {
                return sum + 1;
            }
            return sum;
        }, 0);
        const checkoutHits = throwsForPlayer.filter((t) => t.is_checkout).length;
        let t20Attempts = 0;
        let t20Hits = 0;
        let t19Attempts = 0;
        let t19Hits = 0;
        let doubleAttempts = 0;
        let doubleHits = 0;
        for (const throwItem of throwsForPlayer) {
            const segment = this.parseClassicSegment(throwItem.segment);
            if (segment == null) {
                const encodedDoubleAttempts = this.extractDoubleAttemptsFromSegment(throwItem.segment);
                if (encodedDoubleAttempts > 0) {
                    doubleAttempts += encodedDoubleAttempts;
                    if (throwItem.is_checkout) {
                        doubleHits += 1;
                    }
                }
                continue;
            }
            const { multiplier, value } = segment;
            if (value === 20) {
                t20Attempts += 1;
                if (throwItem.score === multiplier * 20) {
                    t20Hits += 1;
                }
            }
            if (value === 19) {
                t19Attempts += 1;
                if (throwItem.score === multiplier * 19) {
                    t19Hits += 1;
                }
            }
            if (multiplier === 2) {
                doubleAttempts += 1;
                if (throwItem.score === value * 2) {
                    doubleHits += 1;
                }
            }
        }
        const bestLegDarts = this.computeBestLegDarts(allLegs, userId);
        return {
            avg,
            highCheckout,
            count180s,
            count140Plus,
            count100Plus,
            checkoutHits,
            checkoutAttempts,
            t20Hits,
            t20Attempts,
            t19Hits,
            t19Attempts,
            doubleHits,
            doubleAttempts,
            bestLegDarts,
        };
    }
    computeBestLegDarts(legs, userId) {
        let best;
        for (const leg of legs) {
            if (leg.winner_id !== userId) {
                continue;
            }
            const playerThrows = (leg.throws ?? [])
                .filter((t) => t.user_id === userId)
                .sort((a, b) => {
                if (a.round_num !== b.round_num)
                    return a.round_num - b.round_num;
                if (a.dart_num !== b.dart_num)
                    return a.dart_num - b.dart_num;
                return a.created_at.getTime() - b.created_at.getTime();
            });
            if (playerThrows.length === 0) {
                continue;
            }
            const looksLikeVisitFlow = playerThrows.every((throwItem) => {
                const segment = throwItem.segment ?? '';
                return segment.startsWith('VISIT_') ||
                    segment.startsWith('CD') ||
                    segment.startsWith('CHECKOUT_D') ||
                    segment === 'BUST';
            });
            let totalDarts;
            if (looksLikeVisitFlow) {
                const checkoutThrow = [...playerThrows].reverse().find((t) => t.is_checkout);
                const checkoutDarts = checkoutThrow == null
                    ? 3
                    : this.extractCheckoutDartsFromSegment(checkoutThrow.segment);
                totalDarts = ((playerThrows.length - 1) * 3) + checkoutDarts;
            }
            else {
                totalDarts = playerThrows.length;
            }
            if (best == null || totalDarts < best) {
                best = totalDarts;
            }
        }
        return best;
    }
    parseClassicSegment(segment) {
        const match = /^(S|D|T)(\d{1,2}|25)$/.exec(segment);
        if (!match) {
            return null;
        }
        const multiplier = match[1] === 'S' ? 1 : (match[1] === 'D' ? 2 : 3);
        const value = Number.parseInt(match[2], 10);
        if (!Number.isFinite(value) || value <= 0) {
            return null;
        }
        return { multiplier, value };
    }
    extractCheckoutDartsFromSegment(segment) {
        const encoded = this.extractDoubleAttemptsFromSegment(segment);
        if (encoded > 0) {
            return Math.max(1, Math.min(3, encoded));
        }
        if (/^D(\d{1,2}|25)$/.test(segment)) {
            return 1;
        }
        return 3;
    }
    computeCurrentPlayerIndex(match, activeLeg, playerCount) {
        const safePlayerCount = Math.max(1, playerCount);
        const completedLegs = this.countCompletedLegs(match);
        const starterIndex = completedLegs % safePlayerCount;
        const throwsInLeg = activeLeg?.throws?.length ?? 0;
        return (starterIndex + (throwsInLeg % safePlayerCount)) % safePlayerCount;
    }
};
exports.MatchesService = MatchesService;
exports.MatchesService = MatchesService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(match_entity_1.Match)),
    __param(1, (0, typeorm_1.InjectRepository)(match_player_entity_1.MatchPlayer)),
    __param(2, (0, typeorm_1.InjectRepository)(set_entity_1.Set)),
    __param(3, (0, typeorm_1.InjectRepository)(leg_entity_1.Leg)),
    __param(4, (0, typeorm_1.InjectRepository)(throw_entity_1.Throw)),
    __param(5, (0, typeorm_1.InjectRepository)(territory_entity_1.Territory)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.DataSource,
        system_gateway_1.SystemGateway,
        match_gateway_1.MatchGateway,
        stats_service_1.StatsService])
], MatchesService);
//# sourceMappingURL=matches.service.js.map