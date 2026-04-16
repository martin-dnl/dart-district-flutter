import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { randomUUID } from 'crypto';
import sharp from 'sharp';
import { mkdir, unlink } from 'fs/promises';
import { join } from 'path';
import { User } from './entities/user.entity';
import { UpdateUserDto } from './dto/update-user.dto';
import { normalizeLimit } from '../../common/utils/normalize-limit';
import { UserBadge } from '../badges/entities/user-badge.entity';
import { Friendship } from '../contacts/entities/friendship.entity';
import { FriendRequest } from '../contacts/entities/friend-request.entity';
import { RefreshToken } from '../auth/entities/refresh-token.entity';
import { UserSetting } from './entities/user-setting.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly repo: Repository<User>,
    @InjectRepository(UserBadge)
    private readonly userBadgeRepo: Repository<UserBadge>,
    @InjectRepository(Friendship)
    private readonly friendshipRepo: Repository<Friendship>,
    @InjectRepository(FriendRequest)
    private readonly friendRequestRepo: Repository<FriendRequest>,
    @InjectRepository(RefreshToken)
    private readonly refreshTokenRepo: Repository<RefreshToken>,
    @InjectRepository(UserSetting)
    private readonly userSettingsRepo: Repository<UserSetting>,
  ) {}

  async findById(id: string) {
    const user = await this.repo.findOne({
      where: { id },
      relations: ['stats', 'club_memberships', 'club_memberships.club'],
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async update(id: string, dto: UpdateUserDto) {
    await this.repo.update(id, dto);
    return this.findById(id);
  }

  async findMyBadges(userId: string) {
    return this.userBadgeRepo.find({
      where: { user_id: userId },
      relations: ['badge'],
      order: { earned_at: 'DESC' },
    });
  }

  async getSettings(userId: string, key?: string) {
    const normalizedKey = (key ?? '').trim();
    if (normalizedKey) {
      const row = await this.userSettingsRepo.findOne({
        where: { user_id: userId, key: normalizedKey },
      });
      return {
        key: normalizedKey,
        value: row?.value ?? null,
      };
    }

    const rows = await this.userSettingsRepo.find({
      where: { user_id: userId },
      order: { key: 'ASC' },
    });
    return rows.map((row) => ({ key: row.key, value: row.value }));
  }

  async upsertSetting(userId: string, key: string, value: string) {
    const normalizedKey = key.trim();
    const normalizedValue = value.trim();

    if (!normalizedKey || normalizedKey.length > 120) {
      throw new BadRequestException('Invalid key');
    }
    if (!normalizedValue) {
      throw new BadRequestException('Invalid value');
    }

    const existing = await this.userSettingsRepo.findOne({
      where: { user_id: userId, key: normalizedKey },
    });

    if (existing) {
      existing.value = normalizedValue;
      const saved = await this.userSettingsRepo.save(existing);
      return { key: saved.key, value: saved.value };
    }

    const created = this.userSettingsRepo.create({
      user_id: userId,
      key: normalizedKey,
      value: normalizedValue,
    });
    const saved = await this.userSettingsRepo.save(created);
    return { key: saved.key, value: saved.value };
  }

  async uploadAvatar(userId: string, file: Express.Multer.File) {
    const user = await this.repo.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    const allowedMimeTypes = new Set([
      'image/jpeg',
      'image/png',
      'image/webp',
    ]);
    if (!allowedMimeTypes.has(file.mimetype)) {
      throw new BadRequestException('Unsupported file type');
    }
    if (file.size > 5 * 1024 * 1024) {
      throw new BadRequestException('File exceeds 5MB');
    }

    const avatarId = randomUUID();
    const uploadsDir = join(process.cwd(), 'uploads', 'avatars');
    await mkdir(uploadsDir, { recursive: true });

    const mdFileName = `${avatarId}_md.webp`;
    const smFileName = `${avatarId}_sm.webp`;
    const mdDiskPath = join(uploadsDir, mdFileName);
    const smDiskPath = join(uploadsDir, smFileName);

    const image = sharp(file.buffer, { failOn: 'none' }).rotate();

    await image
      .clone()
      .resize(200, 200, { fit: 'cover', position: 'center' })
      .webp({ quality: 80 })
      .toFile(mdDiskPath);

    await image
      .clone()
      .resize(64, 64, { fit: 'cover', position: 'center' })
      .webp({ quality: 70 })
      .toFile(smDiskPath);

    const mdPublicUrl = `/uploads/avatars/${mdFileName}`;
    const smPublicUrl = `/uploads/avatars/${smFileName}`;

    const oldAvatar = user.avatar_url;
    user.avatar_url = mdPublicUrl;
    await this.repo.save(user);

    if (oldAvatar && oldAvatar.includes('/avatars/')) {
      const oldMdName = oldAvatar.split('/').pop();
      if (oldMdName) {
        const oldSmName = oldMdName.replace('_md.webp', '_sm.webp');
        await Promise.allSettled([
          unlink(join(uploadsDir, oldMdName)),
          unlink(join(uploadsDir, oldSmName)),
        ]);
      }
    }

    return {
      avatar_md_url: mdPublicUrl,
      avatar_sm_url: smPublicUrl,
      avatar_url: mdPublicUrl,
    };
  }

  async search(query: string, limit = 20, excludeUserId?: string) {
    const normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) {
      return [];
    }

    const take = normalizeLimit(limit, 20);

    const qb = this.repo
      .createQueryBuilder('u')
      .where('u.username ILIKE :q', { q: `%${normalizedQuery}%` })
      .orderBy('u.elo', 'DESC')
      .take(take);

    if (excludeUserId) {
      qb.andWhere('u.id != :excludeUserId', { excludeUserId });
    }

    return qb.getMany();
  }

  async leaderboard(
    limit = 50,
    metric: 'elo' | 'conquest' = 'elo',
    query?: string,
  ) {
    const take = normalizeLimit(limit, 50);
    const qb = this.repo
      .createQueryBuilder('u')
      .select([
        'u.id',
        'u.username',
        'u.avatar_url',
        'u.elo',
        'u.conquest_score',
        'u.level',
      ])
      .where('u.is_active = true')
      .take(take);

    const normalizedQuery = (query ?? '').trim();
    if (normalizedQuery.length > 0) {
      qb.andWhere('u.username ILIKE :query', {
        query: `%${normalizedQuery}%`,
      });
    }

    if (metric === 'conquest') {
      qb.orderBy('u.conquest_score', 'DESC').addOrderBy('u.elo', 'DESC');
    } else {
      qb.orderBy('u.elo', 'DESC').addOrderBy('u.conquest_score', 'DESC');
    }

    return qb.getMany();
  }

  async remove(id: string) {
    const user = await this.repo.findOne({ where: { id } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    const baseCount = await this.repo
      .createQueryBuilder('u')
      .where("u.username LIKE 'deleted#%'")
      .getCount();

    let cursor = baseCount + 1;
    let candidate = `deleted#${String(cursor).padStart(4, '0')}`;

    while (await this.repo.findOne({ where: { username: candidate } })) {
      cursor += 1;
      candidate = `deleted#${String(cursor).padStart(4, '0')}`;
    }

    await this.friendshipRepo.delete([
      { user_id: id },
      { friend_id: id },
    ]);

    await this.friendRequestRepo.delete([
      { sender_id: id },
      { receiver_id: id },
    ]);

    await this.refreshTokenRepo.update({ user_id: id }, { revoked: true });

    await this.repo.update(id, {
      username: candidate,
      email: null,
      avatar_url: null,
      password_hash: null,
      is_active: false,
    });

    return { success: true };
  }
}
