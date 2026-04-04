import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, Brackets } from 'typeorm';
import { Match } from './entities/match.entity';
import { MatchPlayer } from './entities/match-player.entity';
import { Set } from './entities/set.entity';
import { Leg } from './entities/leg.entity';
import { Throw } from './entities/throw.entity';
import { CreateMatchDto } from './dto/create-match.dto';
import { SubmitThrowDto } from './dto/submit-throw.dto';
import { SystemGateway } from '../realtime/gateways/system.gateway';
import { MatchGateway } from '../realtime/gateways/match.gateway';
import { normalizeLimit } from '../../common/utils/normalize-limit';

@Injectable()
export class MatchesService {
  constructor(
    @InjectRepository(Match) private readonly matchRepo: Repository<Match>,
    @InjectRepository(MatchPlayer)
    private readonly playerRepo: Repository<MatchPlayer>,
    @InjectRepository(Set) private readonly setRepo: Repository<Set>,
    @InjectRepository(Leg) private readonly legRepo: Repository<Leg>,
    @InjectRepository(Throw) private readonly throwRepo: Repository<Throw>,
    private readonly dataSource: DataSource,
    private readonly systemGateway: SystemGateway,
    private readonly matchGateway: MatchGateway,
  ) {}

  async createInvitation(
    inviterId: string,
    body: {
      invitee_id: string;
      mode?: string;
      starting_score?: number;
      sets_to_win?: number;
      legs_per_set?: number;
      finish_type?: string;
      is_ranked?: boolean;
      is_territorial?: boolean;
    },
  ) {
    if (!body.invitee_id) {
      throw new BadRequestException('invitee_id is required');
    }
    if (body.invitee_id === inviterId) {
      throw new BadRequestException('Cannot invite yourself');
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
      const match = queryRunner.manager.create(Match, {
        mode,
        finish: finishType,
        total_sets: setsToWin,
        legs_per_set: legsPerSet,
        is_ranked: body.is_ranked ?? false,
        is_territorial: body.is_territorial ?? false,
        status: 'pending',
        inviter_id: inviterId,
        invitee_id: body.invitee_id,
        invitation_status: 'pending',
        invitation_created_at: new Date(),
      });
      await queryRunner.manager.save(match);

      const home = queryRunner.manager.create(MatchPlayer, {
        match,
        user: { id: inviterId } as MatchPlayer['user'],
        side: 'home',
      });
      const away = queryRunner.manager.create(MatchPlayer, {
        match,
        user: { id: body.invitee_id } as MatchPlayer['user'],
        side: 'away',
      });
      await queryRunner.manager.save([home, away]);

      const firstSet = queryRunner.manager.create(Set, {
        match,
        set_number: 1,
      });
      await queryRunner.manager.save(firstSet);

      const firstLeg = queryRunner.manager.create(Leg, {
        set: firstSet,
        leg_number: 1,
        starting_score: startingScore,
      });
      await queryRunner.manager.save(firstLeg);

      await queryRunner.commitTransaction();

      const serialized = await this.loadSerializedMatch(match.id);
      this.systemGateway.emitUserEvent(
        body.invitee_id,
        'match_invitation',
        serialized,
      );
      return serialized;
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }

  async getOngoingForUser(userId: string) {
    const matches = await this.matchRepo
      .createQueryBuilder('m')
      .innerJoin('m.players', 'mp', 'mp.user_id = :userId', { userId })
      .where('m.status = :inProgress', {
        inProgress: 'in_progress',
      })
      .orWhere(
        new Brackets((qb) => {
          qb.where('m.status = :pending', { pending: 'pending' }).andWhere(
            'm.invitation_status = :invitationPending',
            { invitationPending: 'pending' },
          );
        }),
      )
      .andWhere('m.status != :cancelled', {
        cancelled: 'cancelled',
      })
      .orderBy('m.created_at', 'DESC')
      .getMany();

    return Promise.all(matches.map((m) => this.loadSerializedMatch(m.id)));
  }

  async acceptInvitation(matchId: string, userId: string) {
    const match = await this.loadMatchWithGraph(matchId);
    if (!match.invitee_id || match.invitee_id !== userId) {
      throw new BadRequestException('Only invitee can accept invitation');
    }
    if (match.invitation_status !== 'pending') {
      throw new BadRequestException('Invitation is no longer pending');
    }

    match.invitation_status = 'accepted';
    match.status = 'in_progress';
    match.started_at = new Date();
    await this.matchRepo.save(match);

    const serialized = await this.loadSerializedMatch(match.id);
    if (match.inviter_id) {
      this.systemGateway.emitUserEvent(
        match.inviter_id,
        'match_invitation_accepted',
        serialized,
      );
    }
    this.systemGateway.emitUserEvent(
      userId,
      'match_invitation_accepted',
      serialized,
    );
    return serialized;
  }

  async refuseInvitation(matchId: string, userId: string) {
    const match = await this.loadMatchWithGraph(matchId);
    if (!match.invitee_id || match.invitee_id !== userId) {
      throw new BadRequestException('Only invitee can refuse invitation');
    }
    if (match.invitation_status !== 'pending') {
      throw new BadRequestException('Invitation is no longer pending');
    }

    match.invitation_status = 'refused';
    match.status = 'cancelled';
    match.ended_at = new Date();

    const serialized = this.serializeMatch(match);
    await this.matchRepo.delete(match.id);

    if (match.inviter_id) {
      this.systemGateway.emitUserEvent(
        match.inviter_id,
        'match_invitation_refused',
        serialized,
      );
    }

    return { ok: true };
  }

  async cancelInvitation(matchId: string, userId: string) {
    const match = await this.loadMatchWithGraph(matchId);
    if (!match.inviter_id || match.inviter_id !== userId) {
      throw new BadRequestException('Only inviter can cancel invitation');
    }
    if (match.invitation_status !== 'pending') {
      throw new BadRequestException('Invitation is no longer pending');
    }

    match.invitation_status = 'refused';
    match.status = 'cancelled';
    match.ended_at = new Date();

    const serialized = this.serializeMatch(match);
    await this.matchRepo.delete(match.id);

    if (match.invitee_id) {
      this.systemGateway.emitUserEvent(
        match.invitee_id,
        'match_invitation_refused',
        serialized,
      );
    }
    return { ok: true };
  }

  async submitScore(
    matchId: string,
    userId: string,
    body: {
      player_index: number;
      score: number;
      doubles_attempted?: number;
      dart_positions?: Array<{
        x: number;
        y: number;
        score?: number;
        label?: string;
      }>;
    },
  ) {
    const score = Math.max(0, Math.floor(body.score ?? 0));
    const match = await this.loadMatchWithGraph(matchId);
    if (match.status !== 'in_progress') {
      throw new BadRequestException('Match is not in progress');
    }

    const players = this.getOrderedPlayers(match);
    if (players.findIndex((p) => p.user_id === userId) < 0) {
      throw new BadRequestException('You are not a player in this match');
    }

    const { leg: activeLeg } = this.getActiveSetAndLeg(match);
    const expectedPlayerIndex = this.computeCurrentPlayerIndex(
      match,
      activeLeg,
      players.length,
    );
    // Server remains authoritative on turn order; client-provided player_index is ignored.
    const targetPlayer = players[expectedPlayerIndex];
    const playerThrows = (activeLeg.throws ?? []).filter(
      (t) => t.user_id === targetPlayer.user_id,
    );
    const thrownTotal = playerThrows.reduce((sum, t) => sum + t.score, 0);
    const remaining = activeLeg.starting_score - thrownTotal - score;

    const roundNumber =
      Math.floor((activeLeg.throws?.length ?? 0) / Math.max(players.length, 1)) +
      1;

    const isDoubleOut = match.finish === 'double_out';
    const isBust = remaining < 0;
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

    if (isCheckout && isDoubleOut) {
      doublesAttempted = body.doubles_attempted ?? 0;
      if (doublesAttempted < 1 || doublesAttempted > 3) {
        throw new BadRequestException(
          'doubles_attempted must be between 1 and 3 for double_out checkout',
        );
      }
      // Keep under throws.segment varchar(10)
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
      user: { id: targetPlayer.user_id } as Throw['user'],
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

  async undoLastThrow(matchId: string, userId: string) {
    const match = await this.loadMatchWithGraph(matchId);
    if (match.status !== 'in_progress') {
      throw new BadRequestException('Match is not in progress');
    }

    const players = this.getOrderedPlayers(match);
    if (!players.some((p) => p.user_id === userId)) {
      throw new BadRequestException('You are not a player in this match');
    }

    const { leg: activeLeg } = this.getActiveSetAndLeg(match);
    const latestThrow = [...(activeLeg.throws ?? [])].sort(
      (a, b) => b.created_at.getTime() - a.created_at.getTime(),
    )[0];

    if (!latestThrow) {
      throw new BadRequestException('No throw to undo');
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

  async abandonMatch(
    matchId: string,
    userId: string,
    body: { surrendered_by_index: number },
  ) {
    const match = await this.loadMatchWithGraph(matchId);
    if (match.status !== 'in_progress') {
      throw new BadRequestException('Match is not in progress');
    }

    const players = this.getOrderedPlayers(match);
    const requesterIsPlayer = players.some((p) => p.user_id === userId);
    if (!requesterIsPlayer) {
      throw new BadRequestException('You are not a player in this match');
    }

    const surrenderedByIndex = Math.floor(body.surrendered_by_index ?? -1);
    if (surrenderedByIndex < 0 || surrenderedByIndex >= players.length) {
      throw new BadRequestException('Invalid surrendered_by_index');
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

  /* ── Create match ── */
  async create(dto: CreateMatchDto) {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const match = queryRunner.manager.create(Match, {
        mode: dto.mode,
        finish:
          dto.finish_type === 'straight_out' ? 'single_out' : dto.finish_type,
        total_sets: dto.best_of_sets,
        legs_per_set: dto.best_of_legs,
        is_territorial: dto.is_territorial ?? false,
        territory_id: dto.territory_id ?? null,
        tournament_id: dto.tournament_id ?? null,
        status: 'in_progress',
        started_at: new Date(),
      });
      await queryRunner.manager.save(match);

      // Create match players
      const sides = ['home', 'away'];
      for (let i = 0; i < dto.player_ids.length; i++) {
        const mp = queryRunner.manager.create(MatchPlayer, {
          match,
          user: { id: dto.player_ids[i] } as any,
          side: sides[i] ?? 'home',
          final_score: 0,
        });
        await queryRunner.manager.save(mp);
      }

      // Create first set and first leg
      const set = queryRunner.manager.create(Set, { match, set_number: 1 });
      await queryRunner.manager.save(set);

      const startingScore = dto.mode === '301' ? 301 : 501;
      const leg = queryRunner.manager.create(Leg, {
        set,
        leg_number: 1,
        starting_score: startingScore,
      });
      await queryRunner.manager.save(leg);

      await queryRunner.commitTransaction();
      return this.findById(match.id);
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }

  /* ── Find match ── */
  async findById(id: string) {
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
    if (!match) throw new NotFoundException('Match not found');
    return match;
  }

  async findByUser(
    userId: string,
    limit = 20,
    offset = 0,
    status?: string,
    ranked?: string,
  ) {
    const take = normalizeLimit(limit, 20);
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

  async getMatchReport(matchId: string) {
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
      throw new NotFoundException('Match not found');
    }

    const orderedPlayers = this.getOrderedPlayers(match);
    const allLegs = (match.sets ?? []).flatMap((s) => s.legs ?? []);
    const allThrows = allLegs.flatMap((l) => l.throws ?? []);

    const finalSets = orderedPlayers.map(
      (p) => (match.sets ?? []).filter((s) => s.winner_id === p.user_id).length,
    );

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
        avg_score:
          throwsForPlayer.length > 0
            ? Number((totalScore / throwsForPlayer.length).toFixed(2))
            : 0,
        legs_won: legsWon,
        count_180: count180,
        count_140_plus: count140Plus,
        count_100_plus: count100Plus,
        checkout_rate:
          checkoutAttempts > 0
            ? Number(((checkoutHits / checkoutAttempts) * 100).toFixed(2))
            : 0,
        highest_checkout: highestCheckout,
      };
    });

    const usernameById = new Map(
      orderedPlayers.map((p) => [p.user_id, p.user?.username ?? 'Unknown']),
    );

    const timeline = (match.sets ?? [])
      .sort((a, b) => a.set_number - b.set_number)
      .flatMap((set) =>
        (set.legs ?? [])
          .sort((a, b) => a.leg_number - b.leg_number)
          .filter((leg) => !!leg.winner_id)
          .map((leg) => ({
            set: set.set_number,
            leg: leg.leg_number,
            winner_username: usernameById.get(leg.winner_id ?? '') ?? 'Unknown',
          })),
      );

    return {
      match_id: match.id,
      mode: match.mode,
      final_sets: finalSets,
      players,
      timeline,
    };
  }

  /* ── Submit throw ── */
  async submitThrow(matchId: string, legId: string, playerId: string, dto: SubmitThrowDto) {
    const leg = await this.legRepo.findOne({
      where: { id: legId },
      relations: ['set', 'set.match'],
    });
    if (!leg) throw new NotFoundException('Leg not found');
    if (leg.set.match.id !== matchId) throw new BadRequestException('Leg does not belong to match');

    // Calculate remaining
    const existingThrows = await this.throwRepo.find({
      where: { leg: { id: legId }, user: { id: playerId } },
    });
    const thrownTotal = existingThrows.reduce((s, t) => s + t.score, 0);
    const remaining = leg.starting_score - thrownTotal - dto.score;

    if (remaining < 0) throw new BadRequestException('Score exceeds remaining');

    const t = this.throwRepo.create({
      leg,
      user: { id: playerId } as any,
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

    // Check if leg is won
    if (remaining === 0) {
      await this.completeLeg(leg, playerId);
    }

    return t;
  }

  /* ── Complete leg → check set → check match ── */
  private async completeLeg(leg: Leg, winnerId: string) {
    await this.legRepo.update(
      { id: leg.id },
      { winner_id: winnerId },
    );

    const setId = leg.set_id ?? leg.set?.id;
    if (!setId) {
      return;
    }

    const set = await this.setRepo.findOne({
      where: { id: setId },
      relations: ['match', 'legs'],
    });
    if (!set) return;

    const match = await this.findById(set.match.id);
    const legsToWin = this.isInvitationFlow(match)
      ? match.legs_per_set
      : Math.ceil(match.legs_per_set / 2);

    // Count legs won by this player in current set
    const legsWon = set.legs.filter((l) => l.winner_id === winnerId).length;

    if (legsWon >= legsToWin) {
      // Set won
      await this.setRepo.update({ id: set.id }, { winner_id: winnerId });
      // Reload match so sets carry the updated winner_id
      const freshMatch = await this.findById(match.id);
      await this.checkMatchCompletion(freshMatch, winnerId);
    } else {
      // New leg
      const newLeg = this.legRepo.create({
        set,
        leg_number: set.legs.length + 1,
        starting_score: this.resolveStartingScore(match.mode),
      });
      await this.legRepo.save(newLeg);
    }
  }

  private async checkMatchCompletion(match: Match, lastSetWinnerId: string) {
    const setsToWin = this.isInvitationFlow(match)
      ? match.total_sets
      : Math.ceil(match.total_sets / 2);
    const setsWon = match.sets.filter((s) => s.winner_id === lastSetWinnerId).length;

    if (setsWon >= setsToWin) {
      // Match won
      match.status = 'completed' as any;
      match.ended_at = new Date();
      await this.matchRepo.save(match);

      // Update match players
      for (const mp of match.players) {
        mp.is_winner = mp.user.id === lastSetWinnerId;
        await this.playerRepo.save(mp);
      }
    } else {
      // New set + first leg
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

  /* ── Validate match (both players confirm) ── */
  async validateMatch(matchId: string, userId: string) {
    const match = await this.findById(matchId);
    const player = match.players.find((p) => p.user.id === userId);
    if (!player) throw new BadRequestException('Not a player in this match');

    if (player.side === 'home') {
      match.validated_by_home = true;
    } else {
      match.validated_by_away = true;
    }

    if (match.validated_by_home && match.validated_by_away) {
      match.status = 'awaiting_validation';
    }

    return this.matchRepo.save(match);
  }

  private async loadMatchWithGraph(id: string) {
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
      throw new NotFoundException('Match not found');
    }
    return match;
  }

  private async loadSerializedMatch(id: string) {
    const match = await this.loadMatchWithGraph(id);
    return this.serializeMatch(match);
  }

  private serializeMatch(match: Match) {
    const players = this.getOrderedPlayers(match);
    const playerCount = Math.max(1, players.length);
    const { set: activeSet, leg: activeLeg } = this.getActiveSetAndLeg(match);
    const startingScore =
      activeLeg?.starting_score ?? this.resolveStartingScore(match.mode);
    const legThrows = [...(activeLeg?.throws ?? [])].sort((a, b) => {
      if (a.round_num !== b.round_num) return a.round_num - b.round_num;
      if (a.dart_num !== b.dart_num) return a.dart_num - b.dart_num;
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
      const legsWon = (activeSet?.legs ?? []).filter(
        (l) => l.winner_id === player.user_id,
      ).length;
      const setsWon = (match.sets ?? []).filter(
        (s) => s.winner_id === player.user_id,
      ).length;
      const average =
        throwScores.length === 0
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
    const currentPlayerIndex =
      match.status === 'in_progress'
        ? this.computeCurrentPlayerIndex(match, activeLeg, playerCount)
        : starterIndex;
    const abandonedByIndex = players.findIndex(
      (p) => p.user_id === match.surrendered_by,
    );

    const roundHistory = allThrows.map((t) => {
      const finalPlayerIndex = players.findIndex((p) => p.user_id === t.user_id);
      return {
        'player_index': finalPlayerIndex < 0 ? 0 : finalPlayerIndex,
        'round': t.round_num,
        'darts': [t.score],
        'total': t.score,
        'is_bust': t.segment == 'BUST',
        'doubles_attempted': this.extractDoubleAttemptsFromSegment(t.segment),
      };
    });

    return {
      'id': match.id,
      'mode': match.mode,
      'starting_score': startingScore,
      'players': serializedPlayers,
      'starting_player_index': starterIndex,
      'current_player_index': currentPlayerIndex,
      'current_round':
          legThrows.length === 0
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
      'abandoned_by_index': abandonedByIndex < 0 ? null : abandonedByIndex,
    };
  }

  private getOrderedPlayers(match: Match) {
    return [...(match.players ?? [])].sort((a, b) => {
      const rank = (side: string) => (side === 'home' ? 0 : 1);
      return rank(a.side) - rank(b.side);
    });
  }

  private getActiveSetAndLeg(match: Match) {
    const sets = [...(match.sets ?? [])].sort((a, b) => a.set_number - b.set_number);
    const activeSet = sets.find((s) => !s.winner_id) ?? sets[sets.length - 1];
    const legs = [...(activeSet?.legs ?? [])].sort((a, b) => a.leg_number - b.leg_number);
    const activeLeg = legs.find((l) => !l.winner_id) ?? legs[legs.length - 1];

    if (!activeSet || !activeLeg) {
      throw new BadRequestException('Match has no active set/leg');
    }

    return { set: activeSet, leg: activeLeg };
  }

  private normalizeMode(raw?: string) {
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

  private normalizeFinishType(raw?: string) {
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

  private resolveStartingScore(mode?: string) {
    if (mode === '301') return 301;
    if (mode === '701') return 701;
    return 501;
  }

  private toClientStatus(status: string) {
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

  private isInvitationFlow(match: Match) {
    return Boolean(match.inviter_id && match.invitee_id);
  }

  private extractDoubleAttemptsFromSegment(segment: string) {
    if (segment.startsWith('CD')) {
      return Number.parseInt(segment.slice(2), 10) || 0;
    }

    // Backward compatibility in case old values already exist.
    if (segment.startsWith('CHECKOUT_D')) {
      return Number.parseInt(segment.replace('CHECKOUT_D', ''), 10) || 0;
    }

    return 0;
  }

  private countCompletedLegs(match: Match) {
    return (match.sets ?? [])
      .flatMap((s) => s.legs ?? [])
      .filter((l) => l.winner_id != null).length;
  }

  private computeCurrentPlayerIndex(
    match: Match,
    activeLeg: Leg | undefined,
    playerCount: number,
  ) {
    const safePlayerCount = Math.max(1, playerCount);
    const completedLegs = this.countCompletedLegs(match);
    const starterIndex = completedLegs % safePlayerCount;
    const throwsInLeg = activeLeg?.throws?.length ?? 0;
    return (starterIndex + (throwsInLeg % safePlayerCount)) % safePlayerCount;
  }
}
