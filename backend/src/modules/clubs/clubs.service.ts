import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Club } from './entities/club.entity';
import { ClubMember } from './entities/club-member.entity';
import { CreateClubDto } from './dto/create-club.dto';
import { UpdateClubDto } from './dto/update-club.dto';
import { normalizeLimit } from '../../common/utils/normalize-limit';

@Injectable()
export class ClubsService {
  constructor(
    @InjectRepository(Club) private readonly clubRepo: Repository<Club>,
    @InjectRepository(ClubMember) private readonly memberRepo: Repository<ClubMember>,
  ) {}

  async create(dto: CreateClubDto, userId: string) {
    const club = this.clubRepo.create(dto);
    await this.clubRepo.save(club);

    // Creator becomes president
    const membership = this.memberRepo.create({
      club,
      user: { id: userId } as any,
      role: 'president',
    });
    await this.memberRepo.save(membership);

    return this.findById(club.id);
  }

  async findAll(limit = 50) {
    const take = normalizeLimit(limit, 50);

    return this.clubRepo.find({
      order: { conquest_points: 'DESC' },
      take,
      relations: ['members'],
    });
  }

  async findById(id: string) {
    const club = await this.clubRepo.findOne({
      where: { id },
      relations: ['members', 'members.user'],
    });
    if (!club) throw new NotFoundException('Club not found');
    return club;
  }

  async update(id: string, dto: UpdateClubDto, userId: string) {
    await this.assertRole(id, userId, ['president']);
    await this.clubRepo.update(id, dto);
    return this.findById(id);
  }

  async addMember(clubId: string, userId: string, role: 'president' | 'captain' | 'player' = 'player') {
    const existing = await this.memberRepo.findOne({
      where: { club: { id: clubId }, user: { id: userId } },
    });
    if (existing) throw new ConflictException('User is already a member');

    const membership = this.memberRepo.create({
      club: { id: clubId } as any,
      user: { id: userId } as any,
      role,
    });
    return this.memberRepo.save(membership);
  }

  async removeMember(clubId: string, targetUserId: string, requesterId: string) {
    if (targetUserId !== requesterId) {
      await this.assertRole(clubId, requesterId, ['president', 'captain']);
    }
    const result = await this.memberRepo.delete({
      club: { id: clubId },
      user: { id: targetUserId },
    });
    if (result.affected === 0) throw new NotFoundException('Membership not found');
  }

  async updateMemberRole(clubId: string, targetUserId: string, role: string, requesterId: string) {
    await this.assertRole(clubId, requesterId, ['president']);
    const membership = await this.memberRepo.findOne({
      where: { club: { id: clubId }, user: { id: targetUserId } },
    });
    if (!membership) throw new NotFoundException('Membership not found');
    membership.role = role as any;
    return this.memberRepo.save(membership);
  }

  async ranking(limit = 50) {
    const take = normalizeLimit(limit, 50);

    return this.clubRepo.find({
      order: { conquest_points: 'DESC' },
      take,
      select: ['id', 'name', 'conquest_points', 'rank'],
    });
  }

  /* ── helpers ── */
  private async assertRole(clubId: string, userId: string, roles: string[]) {
    const m = await this.memberRepo.findOne({
      where: { club: { id: clubId }, user: { id: userId } },
    });
    if (!m || !roles.includes(m.role)) {
      throw new ForbiddenException('Insufficient club privileges');
    }
  }
}
