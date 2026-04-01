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

  async findAll(limit = 50, q?: string, city?: string) {
    const take = normalizeLimit(limit, 50);
    const qb = this.clubRepo
      .createQueryBuilder('club')
      .leftJoinAndSelect('club.members', 'members')
      .orderBy('club.conquest_points', 'DESC')
      .take(take);

    if (q) {
      qb.andWhere('(club.name ILIKE :q OR club.city ILIKE :q)', {
        q: `%${q}%`,
      });
    }

    if (city) {
      qb.andWhere('club.city ILIKE :city', { city: `%${city}%` });
    }

    return qb.getMany();
  }

  async search(params: {
    q?: string;
    lat?: number;
    lng?: number;
    radius?: number;
    limit?: number;
  }) {
    const queryValue = (params.q ?? '').trim().toLowerCase();
    const likeTerm = `%${queryValue}%`;
    const take = normalizeLimit(params.limit ?? 20, 50);

    const hasGeo = Number.isFinite(params.lat) && Number.isFinite(params.lng);
    const radiusKm =
      Number.isFinite(params.radius) && (params.radius ?? 0) > 0
        ? Number(params.radius)
        : 20;

    const qb = this.clubRepo
      .createQueryBuilder('club')
      .leftJoinAndSelect('club.members', 'members')
      .take(take);

    if (queryValue.length > 0) {
      qb.andWhere('(LOWER(club.name) LIKE :q OR LOWER(club.city) LIKE :q)', {
        q: likeTerm,
      });
    }

    if (hasGeo) {
      const lat = Number(params.lat);
      const lng = Number(params.lng);
      const distanceExpr = `(
        6371 * acos(
          cos(radians(:lat)) *
          cos(radians(CAST(club.latitude AS double precision))) *
          cos(radians(CAST(club.longitude AS double precision)) - radians(:lng)) +
          sin(radians(:lat)) * sin(radians(CAST(club.latitude AS double precision)))
        )
      )`;

      qb.andWhere('club.latitude IS NOT NULL AND club.longitude IS NOT NULL')
        .addSelect(distanceExpr, 'distance')
        .andWhere(`${distanceExpr} <= :radiusKm`)
        .setParameters({ lat, lng, radiusKm })
        .orderBy('distance', 'ASC');
    } else {
      qb.orderBy('club.name', 'ASC');
    }

    return qb.getMany();
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
