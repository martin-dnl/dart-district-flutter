import { NotificationsService } from './notifications.service';
export declare class NotificationsController {
    private readonly notificationsService;
    constructor(notificationsService: NotificationsService);
    findAll(req: {
        user: {
            id: string;
        };
    }, limit?: number): Promise<import("./entities/notification.entity").Notification[]>;
    unreadCount(req: {
        user: {
            id: string;
        };
    }): Promise<number>;
    markRead(id: string, req: {
        user: {
            id: string;
        };
    }): Promise<import("./entities/notification.entity").Notification>;
    markAllRead(req: {
        user: {
            id: string;
        };
    }): Promise<void>;
}
