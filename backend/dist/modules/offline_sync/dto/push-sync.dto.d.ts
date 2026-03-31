export declare class PushSyncDto {
    entity_type: string;
    entity_id?: string;
    action: 'create' | 'update' | 'delete';
    payload: Record<string, unknown>;
}
