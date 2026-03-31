import { Server, Socket } from 'socket.io';
import { Repository } from 'typeorm';
import { DirectMessage } from '../entities/direct-message.entity';
export declare class SystemGateway {
    private readonly directMessageRepo;
    server: Server;
    constructor(directMessageRepo: Repository<DirectMessage>);
    handleSubscribeUser(client: Socket, data: {
        user_id: string;
    }): {
        event: string;
    };
    handleSubscribeClub(client: Socket, data: {
        club_id: string;
    }): {
        event: string;
    };
    handleQrScan(client: Socket, data: {
        qr_code: string;
        user_id: string;
    }): void;
    handleDirectMessage(client: Socket, data: {
        from_user_id: string;
        to_user_id: string;
        content: string;
    }): Promise<{
        event: string;
    }>;
    emitNotification(userId: string, payload: unknown): void;
    emitClubEvent(clubId: string, event: string, payload: unknown): void;
    emitSyncComplete(userId: string, payload: unknown): void;
    emitUserEvent(userId: string, event: string, payload: unknown): void;
}
