import { User } from '../../users/entities/user.entity';
export declare class OfflineQueue {
    id: string;
    user_id: string;
    entity_type: string;
    entity_id: string | null;
    action: string;
    payload: Record<string, unknown>;
    client_ts: Date;
    processed: boolean;
    processed_at: Date | null;
    conflict: boolean;
    conflict_detail: string | null;
    created_at: Date;
    user: User;
}
