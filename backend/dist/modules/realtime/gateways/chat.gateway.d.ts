import { Server, Socket } from 'socket.io';
import { Repository } from 'typeorm';
import { ChatMessage } from '../entities/chat-message.entity';
export declare class ChatGateway {
    private readonly chatRepo;
    server: Server;
    constructor(chatRepo: Repository<ChatMessage>);
    handleJoinChat(client: Socket, data: {
        match_id: string;
    }): {
        event: string;
        match_id: string;
    };
    handleMessage(client: Socket, data: {
        match_id: string;
        user_id: string;
        content: string;
    }): Promise<void>;
}
