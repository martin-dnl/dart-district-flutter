import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Tournament } from './entities/tournament.entity';
import { TournamentPlayer } from './entities/tournament-player.entity';
import { TournamentPool } from './entities/tournament-pool.entity';
import { TournamentPoolStanding } from './entities/tournament-pool-standing.entity';
import { TournamentBracketMatch } from './entities/tournament-bracket-match.entity';
import { CreateTournamentDto } from './dto/create-tournament.dto';
import { User } from '../users/entities/user.entity';
import { ClubMember } from '../clubs/entities/club-member.entity';

type FindAllOptions = {
  status?: string;
  upcoming?: string;
  clubId?: string;
};

@Injectable()
export class TournamentsService {
  constructor(
    @InjectRepository(Tournament)
    private readonly tournamentRepo: Repository<Tournament>,
    @InjectRepository(TournamentPlayer)
    private readonly playerRepo: Repository<TournamentPlayer>,
    @InjectRepository(TournamentPool)
    private readonly poolRepo: Repository<TournamentPool>,
    @InjectRepository(TournamentPoolStanding)
    private readonly standingRepo: Repository<TournamentPoolStanding>,
    @InjectRepository(TournamentBracketMatch)
    private readonly bracketRepo: Repository<TournamentBracketMatch>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(ClubMember)
    private readonly clubMemberRepo: Repository<ClubMember>,
  ) {}

  async canCreateForClub(userId: string, clubId: string) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (user.is_admin) {
      return true;
    }

    const membership = await this.clubMemberRepo.findOne({
      where: {
        club_id: clubId,
        user_id: userId,
        is_active: true,
      },
    });

    return membership?.role === 'president';
  }

  async create(dto: CreateTournamentDto, userId: string) {
    if (dto.club_id) {
      const canCreateForClub = await this.canCreateForClub(userId, dto.club_id);
      if (!canCreateForClub) {
        throw new ForbiddenException(
          'Only an admin or the club president can create a club tournament',
        );
      }
    }

    const isTerritorial = dto.is_territorial ?? false;
    const isRanked = dto.is_ranked ?? false;

    const poolCount =
      dto.format === 'pools_then_elimination' ? (dto.pool_count ?? 4) : null;
    const playersPerPool =
      dto.format === 'pools_then_elimination' && poolCount
        ? Math.ceil(dto.max_players / poolCount)
        : null;

    const tournament = this.tournamentRepo.create({
      ...dto,
      club_id: dto.club_id ?? null,
      is_territorial: isTerritorial,
      is_ranked: isTerritorial ? true : isRanked,
      current_phase: 'registration',
      pool_count: poolCount,
      players_per_pool: playersPerPool,
      creator: { id: userId } as any,
    });
    return this.tournamentRepo.save(tournament);
  }

  async findAll(options?: FindAllOptions) {
    const qb = this.tournamentRepo
      .createQueryBuilder('t')
      .leftJoinAndSelect('t.territory', 'territory')
      .leftJoinAndSelect('t.creator', 'creator')
      .leftJoinAndSelect('t.club', 'club')
      .orderBy('t.scheduled_at', 'ASC');

    if (options?.status) {
      qb.andWhere('t.status = :status', { status: options.status });
    }
    if (options?.clubId) {
      qb.andWhere('t.club_id = :clubId', { clubId: options.clubId });
    }
    if (options?.upcoming === 'true') {
      qb.andWhere('t.scheduled_at > :now', { now: new Date() });
    }
    if (!options?.status && options?.upcoming !== 'false') {
      qb.andWhere('t.scheduled_at > :now', { now: new Date() });
    }

    return qb.getMany();
  }

  async findById(id: string) {
    const t = await this.tournamentRepo.findOne({
      where: { id },
      relations: ['territory', 'creator', 'club'],
    });
    if (!t) throw new NotFoundException('Tournament not found');

    const players = await this.playerRepo.find({
      where: { tournament_id: id },
      relations: ['user', 'pool'],
      order: { registered_at: 'ASC' },
    });

    return { ...t, players };
  }

  async registerPlayer(tournamentId: string, userId: string) {
    const tournament = await this.tournamentRepo.findOne({
      where: { id: tournamentId },
    });
    if (!tournament) throw new NotFoundException('Tournament not found');
    if (tournament.current_phase !== 'registration') {
      throw new BadRequestException('Registration phase is closed');
    }

    const playerCount = await this.playerRepo.count({
      where: { tournament_id: tournamentId },
    });
    if (playerCount >= tournament.max_players) {
      throw new BadRequestException('Tournament is full');
    }

    const existing = await this.playerRepo.findOne({
      where: { tournament_id: tournamentId, user_id: userId },
    });
    if (existing) throw new BadRequestException('Player already registered');

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

  async unregisterPlayer(tournamentId: string, userId: string) {
    const tournament = await this.tournamentRepo.findOne({
      where: { id: tournamentId },
    });
    if (!tournament) throw new NotFoundException('Tournament not found');
    if (tournament.current_phase !== 'registration') {
      throw new BadRequestException('Registration phase is closed');
    }

    const result = await this.playerRepo.delete({
      tournament_id: tournamentId,
      user_id: userId,
    });
    if (result.affected === 0) throw new NotFoundException('Registration not found');

    const remaining = await this.playerRepo.count({
      where: { tournament_id: tournamentId },
    });
    await this.tournamentRepo.update(tournamentId, { enrolled_players: remaining });
  }

  async getPools(tournamentId: string) {
    return this.poolRepo.find({
      where: { tournament_id: tournamentId },
      relations: ['players', 'players.user'],
      order: { pool_name: 'ASC' },
    });
  }

  async generatePools(tournamentId: string, userId: string) {
    const tournament = await this.assertCreator(tournamentId, userId);
    if (tournament.current_phase !== 'registration') {
      throw new BadRequestException('Pools can only be generated from registration phase');
    }

    const players = await this.playerRepo.find({
      where: { tournament_id: tournamentId, is_disqualified: false },
      relations: ['user'],
      order: { seed: 'ASC' },
    });
    if (players.length < 2) {
      throw new BadRequestException('Not enough players to generate pools');
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

    // Serpentine distribution: A->B->C then reverse C->B->A.
    let direction = 1;
    let currentIndex = 0;
    const updates: Array<Promise<unknown>> = [];
    const standingRows: TournamentPoolStanding[] = [];
    for (const player of players) {
      const pool = savedPools[currentIndex];
      updates.push(
        this.playerRepo.update(player.id, {
          pool_id: pool.id,
          is_qualified: false,
        }),
      );

      standingRows.push(
        this.standingRepo.create({
          pool_id: pool.id,
          user_id: player.user_id,
          matches_played: 0,
          matches_won: 0,
          legs_won: 0,
          legs_lost: 0,
          points: 0,
          rank: null,
        }),
      );

      if (direction > 0) {
        if (currentIndex === savedPools.length - 1) {
          direction = -1;
        } else {
          currentIndex += 1;
        }
      } else if (currentIndex === 0) {
        direction = 1;
      } else {
        currentIndex -= 1;
      }
    }
    await Promise.all(updates);
    await this.standingRepo.save(standingRows);

    tournament.current_phase = 'pools';
    await this.tournamentRepo.save(tournament);
    return savedPools;
  }

  async getPoolStandings(poolId: string) {
    return this.standingRepo.find({
      where: { pool_id: poolId },
      relations: ['user'],
      order: { points: 'DESC', rank: 'ASC' },
    });
  }

  async updatePoolResult(_poolId: string, _matchId: string) {
    // Reserved for future wiring with matches completion callbacks.
    return;
  }

  async generateBracket(tournamentId: string, userId: string) {
    const tournament = await this.assertCreator(tournamentId, userId);
    if (tournament.current_phase !== 'pools' && tournament.current_phase !== 'registration') {
      throw new BadRequestException('Bracket can only be generated from registration or pools phase');
    }

    const players = await this.getQualifiedPlayers(tournament);
    if (players.length < 2) {
      throw new BadRequestException('Not enough players to generate bracket');
    }

    await this.bracketRepo.delete({ tournament_id: tournamentId });

    const bracketSize = this.nextPowerOfTwo(players.length);
    const firstRoundNumber = bracketSize / 2;
    const bracketSlots: Array<TournamentPlayer | null> = [
      ...players,
      ...Array.from(
        { length: bracketSize - players.length },
        () => null as TournamentPlayer | null,
      ),
    ];

    const firstRoundMatches: TournamentBracketMatch[] = [];
    for (let i = 0; i < firstRoundNumber; i += 1) {
      const player1 = bracketSlots[i];
      const player2 = bracketSlots[bracketSize - 1 - i];
      const isBye = !player1 || !player2;

      firstRoundMatches.push(
        this.bracketRepo.create({
          tournament_id: tournamentId,
          round_number: firstRoundNumber,
          position: i + 1,
          player1_id: player1?.user_id ?? null,
          player2_id: player2?.user_id ?? null,
          winner_id: isBye ? (player1?.user_id ?? player2?.user_id ?? null) : null,
          status: isBye ? 'completed' : 'pending',
          match_id: null,
          scheduled_at: null,
        }),
      );
    }
    const saved = await this.bracketRepo.save(firstRoundMatches);

    let round = firstRoundNumber / 2;
    while (round >= 1) {
      const matchCount = round;
      const rows: TournamentBracketMatch[] = [];
      for (let i = 0; i < matchCount; i += 1) {
        rows.push(
          this.bracketRepo.create({
            tournament_id: tournamentId,
            round_number: round,
            position: i + 1,
            player1_id: null,
            player2_id: null,
            winner_id: null,
            match_id: null,
            status: 'pending',
            scheduled_at: null,
          }),
        );
      }
      await this.bracketRepo.save(rows);
      round /= 2;
    }

    tournament.current_phase = 'bracket';
    await this.tournamentRepo.save(tournament);
    return saved;
  }

  async getBracket(tournamentId: string) {
    return this.bracketRepo.find({
      where: { tournament_id: tournamentId },
      relations: ['player1', 'player2', 'winner'],
      order: { round_number: 'DESC', position: 'ASC' },
    });
  }

  async advancePhase(tournamentId: string, userId: string) {
    const tournament = await this.assertCreator(tournamentId, userId);
    const order = ['registration', 'pools', 'bracket', 'finished'];
    const index = order.indexOf(tournament.current_phase);
    if (index === -1 || index >= order.length - 1) {
      throw new BadRequestException('Tournament phase cannot be advanced');
    }
    tournament.current_phase = order[index + 1];
    return this.tournamentRepo.save(tournament);
  }

  async disqualifyPlayer(
    tournamentId: string,
    playerId: string,
    reason: string,
    requesterId: string,
  ) {
    await this.assertCreator(tournamentId, requesterId);
    const player = await this.playerRepo.findOne({
      where: { tournament_id: tournamentId, user_id: playerId },
    });
    if (!player) {
      throw new NotFoundException('Player not found in tournament');
    }
    await this.playerRepo.update(player.id, {
      is_disqualified: true,
      disqualification_reason: reason,
      is_qualified: false,
    });
  }

  private async assertCreator(tournamentId: string, userId: string) {
    const tournament = await this.tournamentRepo.findOne({
      where: { id: tournamentId },
    });
    if (!tournament) {
      throw new NotFoundException('Tournament not found');
    }
    if (tournament.created_by !== userId) {
      throw new ForbiddenException('Only tournament creator can perform this action');
    }
    return tournament;
  }

  private async getQualifiedPlayers(tournament: Tournament) {
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

  private nextPowerOfTwo(value: number) {
    let n = 1;
    while (n < value) {
      n *= 2;
    }
    return n;
  }
}
