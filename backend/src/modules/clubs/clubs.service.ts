import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { Club } from './entities/club.entity';
import { ClubMember } from './entities/club-member.entity';
import { ClubTerritoryPoints } from './entities/club-territory-points.entity';
import { CreateClubDto } from './dto/create-club.dto';
import { UpdateClubDto } from './dto/update-club.dto';
import { normalizeLimit } from '../../common/utils/normalize-limit';

@Injectable()
export class ClubsService {
  private readonly logger = new Logger(ClubsService.name);

  constructor(
    @InjectRepository(Club) private readonly clubRepo: Repository<Club>,
    @InjectRepository(ClubMember) private readonly memberRepo: Repository<ClubMember>,
    @InjectRepository(ClubTerritoryPoints)
    private readonly ctpRepo: Repository<ClubTerritoryPoints>,
    private readonly dataSource: DataSource,
  ) {}

  async create(dto: CreateClubDto, _userId: string) {
    let resolvedCodeIris = dto.code_iris ?? null;
    if (!resolvedCodeIris && dto.latitude != null && dto.longitude != null) {
      resolvedCodeIris = await this.resolveNearestCodeIris(dto.latitude, dto.longitude);
    }

    const club = this.clubRepo.create({
      ...dto,
      country: dto.country ?? 'France',
    });
    club.code_iris = resolvedCodeIris;
    await this.clubRepo.save(club);

    if (club.code_iris) {
      const existingCtp = await this.ctpRepo.findOne({
        where: { club_id: club.id, code_iris: club.code_iris },
      });

      if (!existingCtp) {
        await this.ctpRepo.save(
          this.ctpRepo.create({
            club_id: club.id,
            code_iris: club.code_iris,
            points: 0,
          }),
        );
      }
    }

    return this.clubRepo.findOne({
      where: { id: club.id },
      relations: ['members', 'members.user'],
    });
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
    this.logger.log(`Club search called: ${JSON.stringify(params)}`);
    try {
      const queryValue = (params.q ?? '').trim().toLowerCase();
      const likeTerm = `%${queryValue}%`;
      const take = normalizeLimit(params.limit ?? 20, 50);

      const hasGeo = Number.isFinite(params.lat) && Number.isFinite(params.lng);
      const hasRadius = Number.isFinite(params.radius) && (params.radius ?? 0) > 0;
      const radiusKm = hasRadius ? Number(params.radius) : null;

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
          .setParameters({ lat, lng })
          .orderBy('distance', 'ASC');

        if (hasRadius) {
          qb.andWhere(`${distanceExpr} <= :radiusKm`).setParameter('radiusKm', radiusKm);
        }
      } else {
        qb.orderBy('club.name', 'ASC');
      }

      return qb.getMany();
    } catch (err) {
      const error = err as Error;
      this.logger.error(`Club search failed: ${error.message}`, error.stack);
      throw err;
    }
  }

  async getMembership(clubId: string, userId: string) {
    return this.memberRepo.findOne({
      where: {
        club_id: clubId,
        user_id: userId,
        is_active: true,
      },
    });
  }

  async getTerritoryTopClubs(codeIris: string, limit = 3) {
    return this.ctpRepo.find({
      where: { code_iris: codeIris.toUpperCase() },
      relations: ['club'],
      order: { points: 'DESC' },
      take: Math.max(1, limit),
    });
  }

  async getTerritoryPointsTotal(clubId: string) {
    const row = await this.ctpRepo
      .createQueryBuilder('ctp')
      .select('COALESCE(SUM(ctp.points), 0)', 'total')
      .where('ctp.club_id = :clubId', { clubId })
      .getRawOne<{ total: string | number }>();

    return {
      club_id: clubId,
      points: Number(row?.total ?? 0),
    };
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

  async findForMap() {
    const clubs = await this.clubRepo.find({
      where: {},
      select: ['id', 'name', 'latitude', 'longitude', 'code_iris', 'city', 'address'],
      order: { name: 'ASC' },
    });

    return clubs
      .filter((club) => club.latitude != null && club.longitude != null)
      .map((club) => ({
        id: club.id,
        name: club.name,
        latitude: Number(club.latitude),
        longitude: Number(club.longitude),
        code_iris: club.code_iris,
        address: club.address,
        city: club.city,
      }));
  }

  async resolveNearestCodeIris(
    latitude: number,
    longitude: number,
    maxDistanceKm = 5,
  ): Promise<string | null> {
    const rows = await this.dataSource.query(
      `
        SELECT code_iris,
               CAST(centroid_lat AS double precision) AS centroid_lat,
               CAST(centroid_lng AS double precision) AS centroid_lng
        FROM territories
        WHERE centroid_lat IS NOT NULL
          AND centroid_lng IS NOT NULL
        ORDER BY (
          6371 * acos(
            cos(radians($1)) *
            cos(radians(CAST(centroid_lat AS double precision))) *
            cos(radians(CAST(centroid_lng AS double precision)) - radians($2)) +
            sin(radians($1)) * sin(radians(CAST(centroid_lat AS double precision)))
          )
        ) ASC
        LIMIT 1
      `,
      [latitude, longitude],
    );

    const nearest = rows?.[0];
    const code = nearest?.code_iris;
    const centroidLat = Number(nearest?.centroid_lat);
    const centroidLng = Number(nearest?.centroid_lng);
    if (
      typeof code !== 'string' ||
      code.length === 0 ||
      !Number.isFinite(centroidLat) ||
      !Number.isFinite(centroidLng)
    ) {
      return null;
    }

    const distanceKm = this.haversineDistanceKm(
      latitude,
      longitude,
      centroidLat,
      centroidLng,
    );
    if (distanceKm > maxDistanceKm) {
      return null;
    }

    return code;
  }

  private haversineDistanceKm(
    fromLat: number,
    fromLng: number,
    toLat: number,
    toLng: number,
  ): number {
    const toRadians = (value: number) => (value * Math.PI) / 180;

    const dLat = toRadians(toLat - fromLat);
    const dLng = toRadians(toLng - fromLng);
    const lat1 = toRadians(fromLat);
    const lat2 = toRadians(toLat);

    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.sin(dLng / 2) * Math.sin(dLng / 2) * Math.cos(lat1) * Math.cos(lat2);

    return 6371 * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
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
