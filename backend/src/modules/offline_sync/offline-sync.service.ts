import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { OfflineQueue } from './entities/offline-queue.entity';
import { PushSyncDto } from './dto/push-sync.dto';

@Injectable()
export class OfflineSyncService {
  private readonly logger = new Logger(OfflineSyncService.name);

  constructor(
    @InjectRepository(OfflineQueue) private readonly queueRepo: Repository<OfflineQueue>,
  ) {}

  async push(userId: string, items: PushSyncDto[]) {
    const results: Array<{ id: string; status: string; conflict: boolean }> = [];

    for (const item of items) {
      const entry = this.queueRepo.create({
        user: { id: userId } as any,
        user_id: userId,
        entity_type: item.entity_type,
        entity_id: item.entity_id ?? null,
        action: item.action,
        payload: item.payload,
        client_ts: new Date(),
      });

      // Simple conflict detection: check if another user modified the same entity
      if (item.entity_id) {
        const conflict = await this.queueRepo.findOne({
          where: {
            entity_type: item.entity_type,
            entity_id: item.entity_id,
            processed: false,
          },
        });

        if (conflict && conflict.user_id !== userId) {
          entry.conflict = true;
          entry.conflict_detail = JSON.stringify(conflict.payload);
          this.logger.warn(`Conflict detected: ${item.entity_type}/${item.entity_id}`);
        }
      }

      const saved = await this.queueRepo.save(entry);
      results.push({
        id: saved.id,
        status: saved.conflict ? 'conflict' : 'queued',
        conflict: saved.conflict,
      });
    }

    return results;
  }

  async pull(userId: string, since?: string) {
    const qb = this.queueRepo
      .createQueryBuilder('q')
      .where('q.user_id = :userId', { userId })
      .andWhere('q.processed = false');

    if (since) {
      qb.andWhere('q.created_at > :since', { since });
    }

    const items = await qb.orderBy('q.created_at', 'ASC').getMany();

    // Mark as synced
    const ids = items.map((i) => i.id);
    if (ids.length > 0) {
      await this.queueRepo
        .createQueryBuilder()
        .update()
        .set({ processed: true, processed_at: new Date() })
        .whereInIds(ids)
        .execute();
    }

    return items;
  }

  async resolveConflict(entryId: string, resolution: 'keep_local' | 'keep_remote') {
    const entry = await this.queueRepo.findOne({ where: { id: entryId } });
    if (!entry) return null;

    if (resolution === 'keep_local') {
      entry.conflict = false;
      entry.conflict_detail = null;
    } else {
      // Discard local change
      entry.processed = true;
      entry.processed_at = new Date();
      entry.conflict = false;
    }
    return this.queueRepo.save(entry);
  }
}
