import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notification } from './entities/notification.entity';
import { normalizeLimit } from '../../common/utils/normalize-limit';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(Notification) private readonly repo: Repository<Notification>,
  ) {}

  async findByUser(userId: string, limit = 50) {
    const take = normalizeLimit(limit, 50);

    return this.repo.find({
      where: { user: { id: userId } },
      order: { created_at: 'DESC' },
      take,
    });
  }

  async create(userId: string, type: string, data: Record<string, unknown>) {
    const n = this.repo.create({
      user: { id: userId } as any,
      type: type as any,
      data,
    });
    return this.repo.save(n);
  }

  async markRead(id: string, userId: string) {
    const n = await this.repo.findOne({
      where: { id, user: { id: userId } },
    });
    if (!n) throw new NotFoundException('Notification not found');
    n.is_read = true;
    return this.repo.save(n);
  }

  async markAllRead(userId: string) {
    await this.repo.update(
      { user: { id: userId }, is_read: false },
      { is_read: true },
    );
  }

  async unreadCount(userId: string) {
    return this.repo.count({
      where: { user: { id: userId }, is_read: false },
    });
  }
}
