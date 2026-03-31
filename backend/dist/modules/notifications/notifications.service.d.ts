import { Repository } from 'typeorm';
import { Notification } from './entities/notification.entity';
export declare class NotificationsService {
    private readonly repo;
    constructor(repo: Repository<Notification>);
    findByUser(userId: string, limit?: number): Promise<Notification[]>;
    create(userId: string, type: string, data: Record<string, unknown>): Promise<Notification>;
    markRead(id: string, userId: string): Promise<Notification>;
    markAllRead(userId: string): Promise<void>;
    unreadCount(userId: string): Promise<number>;
}
