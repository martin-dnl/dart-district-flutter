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

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly repo: Repository<User>,
    @InjectRepository(UserBadge)
    private readonly userBadgeRepo: Repository<UserBadge>,
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

  async search(query: string, limit = 20) {
    const take = normalizeLimit(limit, 20);

    return this.repo
      .createQueryBuilder('u')
      .where('u.username ILIKE :q', { q: `%${query}%` })
      .orderBy('u.elo', 'DESC')
      .take(take)
      .getMany();
  }

  async leaderboard(limit = 50) {
    const take = normalizeLimit(limit, 50);

    return this.repo.find({
      order: { elo: 'DESC' },
      take,
      select: ['id', 'username', 'avatar_url', 'elo', 'level'],
    });
  }

  async remove(id: string) {
    const result = await this.repo.softDelete(id);
    if (result.affected === 0) throw new NotFoundException('User not found');
  }
}
