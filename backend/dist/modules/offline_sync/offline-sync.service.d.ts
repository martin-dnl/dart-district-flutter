import { Repository } from 'typeorm';
import { OfflineQueue } from './entities/offline-queue.entity';
import { PushSyncDto } from './dto/push-sync.dto';
export declare class OfflineSyncService {
    private readonly queueRepo;
    private readonly logger;
    constructor(queueRepo: Repository<OfflineQueue>);
    push(userId: string, items: PushSyncDto[]): Promise<{
        id: string;
        status: string;
        conflict: boolean;
    }[]>;
    pull(userId: string, since?: string): Promise<OfflineQueue[]>;
    resolveConflict(entryId: string, resolution: 'keep_local' | 'keep_remote'): Promise<OfflineQueue | null>;
}
