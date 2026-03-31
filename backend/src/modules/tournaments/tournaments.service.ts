import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan } from 'typeorm';
import { Tournament } from './entities/tournament.entity';
import { TournamentRegistration } from './entities/tournament-registration.entity';

@Injectable()
export class TournamentsService {
  constructor(
    @InjectRepository(Tournament) private readonly tournamentRepo: Repository<Tournament>,
    @InjectRepository(TournamentRegistration) private readonly regRepo: Repository<TournamentRegistration>,
  ) {}

  async create(dto: Partial<Tournament>, userId: string) {
    const tournament = this.tournamentRepo.create({
      ...dto,
      creator: { id: userId } as any,
    });
    return this.tournamentRepo.save(tournament);
  }

  async findAll() {
    return this.tournamentRepo.find({
      where: { scheduled_at: MoreThan(new Date()) },
      relations: ['territory', 'creator'],
      order: { scheduled_at: 'ASC' },
    });
  }

  async findById(id: string) {
    const t = await this.tournamentRepo.findOne({
      where: { id },
      relations: ['territory', 'creator'],
    });
    if (!t) throw new NotFoundException('Tournament not found');

    const registrations = await this.regRepo.find({
      where: { tournament_id: id },
      relations: ['club', 'registrant'],
    });

    return { ...t, registrations };
  }

  async registerClub(tournamentId: string, clubId: string, userId: string) {
    const tournament = await this.findById(tournamentId);
    const registrations = await this.regRepo.find({
      where: { tournament_id: tournamentId },
      relations: ['club'],
    });

    if (registrations.length >= tournament.max_clubs) {
      throw new BadRequestException('Tournament is full');
    }

    const existing = registrations.find((registration) => registration.club_id === clubId);
    if (existing) throw new BadRequestException('Club already registered');

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

  async unregisterClub(tournamentId: string, clubId: string) {
    const result = await this.regRepo.delete({
      tournament_id: tournamentId,
      club_id: clubId,
    });
    if (result.affected === 0) throw new NotFoundException('Registration not found');

    const remaining = await this.regRepo.count({
      where: { tournament_id: tournamentId },
    });
    await this.tournamentRepo.update(tournamentId, { enrolled_clubs: remaining });
  }
}
