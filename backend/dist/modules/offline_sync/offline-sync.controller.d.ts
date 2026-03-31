import { OfflineSyncService } from './offline-sync.service';
import { PushSyncDto } from './dto/push-sync.dto';
export declare class OfflineSyncController {
    private readonly syncService;
    constructor(syncService: OfflineSyncService);
    push(req: {
        user: {
            id: string;
        };
    }, items: PushSyncDto[]): Promise<{
        id: string;
        status: string;
        conflict: boolean;
    }[]>;
    pull(req: {
        user: {
            id: string;
        };
    }, since?: string): Promise<import("./entities/offline-queue.entity").OfflineQueue[]>;
    resolve(id: string, resolution: 'keep_local' | 'keep_remote'): Promise<import("./entities/offline-queue.entity").OfflineQueue | null>;
}
