import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PlayerStat } from './entities/player-stat.entity';
import { EloHistory } from './entities/elo-history.entity';
import { User } from '../users/entities/user.entity';
import { normalizeLimit } from '../../common/utils/normalize-limit';
import { Throw } from '../matches/entities/throw.entity';
import { Match } from '../matches/entities/match.entity';
import { ClubMember } from '../clubs/entities/club-member.entity';
import { ClubTerritoryPoints } from '../clubs/entities/club-territory-points.entity';
import { Territory } from '../territories/entities/territory.entity';

const K_FACTOR = 32;

@Injectable()
export class StatsService {
  constructor(
    @InjectRepository(PlayerStat) private readonly statRepo: Repository<PlayerStat>,
    @InjectRepository(EloHistory) private readonly eloRepo: Repository<EloHistory>,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(Throw) private readonly throwRepo: Repository<Throw>,
    @InjectRepository(Match) private readonly matchRepo: Repository<Match>,
    @InjectRepository(ClubMember)
    private readonly clubMemberRepo: Repository<ClubMember>,
    @InjectRepository(ClubTerritoryPoints)
    private readonly ctpRepo: Repository<ClubTerritoryPoints>,
    @InjectRepository(Territory)
    private readonly territoryRepo: Repository<Territory>,
  ) {}

  private readonly territoryControlMinPoints = Math.max(
    1,
    Number(process.env.TERRITORY_CONTROL_MIN_POINTS ?? 200),
  );

  /* ── Player Stats ── */

  async getByUser(userId: string) {
    const stat = await this.statRepo.findOne({
      where: { user: { id: userId } },
    });
    if (!stat) throw new NotFoundException('Stats not found');
    return stat;
  }

  async updateAfterMatch(userId: string, matchData: {
    avg: number;
    highCheckout: number;
    count180s: number;
    count140Plus: number;
    count100Plus: number;
    checkoutHits: number;
    checkoutAttempts: number;
    t20Hits: number;
    t20Attempts: number;
    t19Hits: number;
    t19Attempts: number;
    doubleHits: number;
    doubleAttempts: number;
    won: boolean;
  }) {
    const stat = await this.statRepo.findOne({
      where: { user: { id: userId } },
    });
    if (!stat) return;

    const total = stat.matches_played + 1;

    // Running average
    stat.avg_score = ((stat.avg_score * stat.matches_played) + matchData.avg) / total;
    stat.best_avg = Math.max(stat.best_avg, matchData.avg);

    stat.matches_played = total;
    if (matchData.won) stat.matches_won += 1;

    if (matchData.highCheckout > stat.high_finish) {
      stat.high_finish = matchData.highCheckout;
    }
    stat.total_180s += matchData.count180s;
    stat.count_140_plus += matchData.count140Plus;
    stat.count_100_plus += matchData.count100Plus;

    // Checkout rate (weighted)
    if (matchData.checkoutAttempts > 0) {
      const matchRate = (matchData.checkoutHits / matchData.checkoutAttempts) * 100;
      stat.checkout_rate = this.weightedRate(
        stat.checkout_rate,
        stat.matches_played - 1,
        matchRate,
      );
    }

    // Precision fields
    if (matchData.t20Attempts > 0) {
      stat.precision_t20 = this.weightedRate(
        stat.precision_t20,
        stat.matches_played - 1,
        (matchData.t20Hits / matchData.t20Attempts) * 100,
      );
    }
    if (matchData.t19Attempts > 0) {
      stat.precision_t19 = this.weightedRate(
        stat.precision_t19,
        stat.matches_played - 1,
        (matchData.t19Hits / matchData.t19Attempts) * 100,
      );
    }
    if (matchData.doubleAttempts > 0) {
      stat.precision_double = this.weightedRate(
        stat.precision_double,
        stat.matches_played - 1,
        (matchData.doubleHits / matchData.doubleAttempts) * 100,
      );
    }

    await this.statRepo.save(stat);
    return stat;
  }

  /* ── ELO Calculation ── */

  async processElo(
    matchId: string,
    winnerId: string,
    loserId: string,
    isRanked = true,
  ) {
    if (!isRanked) {
      return null;
    }

    const winner = await this.userRepo.findOne({ where: { id: winnerId } });
    const loser = await this.userRepo.findOne({ where: { id: loserId } });
    if (!winner || !loser) return;

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

    // History entries
    await this.eloRepo.save(
      this.eloRepo.create({
        user_id: winner.id,
        match_id: matchId,
        elo_before: winnerBefore,
        elo_after: winner.elo,
        delta: deltaWinner,
      }),
    );
    await this.eloRepo.save(
      this.eloRepo.create({
        user_id: loser.id,
        match_id: matchId,
        elo_before: loserBefore,
        elo_after: loser.elo,
        delta: deltaLoser,
      }),
    );

    return { winner: { elo: winner.elo, delta: deltaWinner }, loser: { elo: loser.elo, delta: deltaLoser } };
  }

  async eloHistory(userId: string, limit = 30) {
    const take = normalizeLimit(limit, 30);

    return this.eloRepo.find({
      where: { user: { id: userId } },
      order: { created_at: 'DESC' },
      take,
    });
  }

  async processTerritoryPoints(params: {
    matchId: string;
    winnerId: string;
    loserId: string;
    eloDelta?: number;
  }) {
    void params.loserId;

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

    if (!winnerMembership) {
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
    await this.recalculateTerritoryControl(codeIris);
    return saved;
  }

  private async recalculateTerritoryControl(codeIris: string) {
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

    const eligible = rows.filter(
      (row) => row.points >= this.territoryControlMinPoints,
    );

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

  async getDartboardPeriods(userId: string) {
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
      .getRawMany<{ year: string; month: string }>();

    const grouped = new Map<number, number[]>();
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

  async getDartboardHeatmap(
    userId: string,
    filter: { period?: string; year?: number; month?: number },
  ) {
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
        throw new BadRequestException('Month period requires valid year and month');
      }
      query.andWhere("EXTRACT(YEAR FROM throw.created_at) = :year", { year });
      query.andWhere("EXTRACT(MONTH FROM throw.created_at) = :month", { month });
    } else if (period == 'year') {
      const year = Number(filter.year);
      if (!Number.isInteger(year)) {
        throw new BadRequestException('Year period requires a valid year');
      }
      query.andWhere("EXTRACT(YEAR FROM throw.created_at) = :year", { year });
    }

    const throws = await query.getMany();
    const hits = throws.flatMap((entry) =>
      (entry.dart_positions ?? [])
        .filter(
          (position) =>
            position &&
            typeof position.x === 'number' &&
            typeof position.y === 'number',
        )
        .map((position) => ({
          x: position.x,
          y: position.y,
          score: typeof position.score === 'number' ? position.score : entry.score,
          label: typeof position.label === 'string' ? position.label : undefined,
          played_at: entry.created_at,
        })),
    );

    return {
      period,
      year: period == 'all' ? null : Number(filter.year ?? 0) || null,
      month: period == 'month' ? Number(filter.month ?? 0) || null : null,
      total_throws: throws.length,
      total_hits: hits.length,
      hits,
    };
  }

  /* ── Helpers ── */
  private normalizePeriod(period?: string) {
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

  private weightedRate(currentRate: number, totalGames: number, newRate: number): number {
    return ((currentRate * totalGames) + newRate) / (totalGames + 1);
  }
}
