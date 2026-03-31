import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ChatMessage } from '../entities/chat-message.entity';

@WebSocketGateway({ namespace: '/ws/chat', cors: { origin: '*' } })
export class ChatGateway {
  @WebSocketServer() server: Server;

  constructor(
    @InjectRepository(ChatMessage) private readonly chatRepo: Repository<ChatMessage>,
  ) {}

  @SubscribeMessage('join_chat')
  handleJoinChat(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { match_id: string },
  ) {
    client.join(`chat:${data.match_id}`);
    return { event: 'joined_chat', match_id: data.match_id };
  }

  @SubscribeMessage('chat_message')
  async handleMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { match_id: string; user_id: string; content: string },
  ) {
    // Persist
    const msg = this.chatRepo.create({
      match: { id: data.match_id } as any,
      user: { id: data.user_id } as any,
      content: data.content,
    });
    await this.chatRepo.save(msg);

    // Broadcast
    this.server.to(`chat:${data.match_id}`).emit('chat_message', {
      id: msg.id,
      user_id: data.user_id,
      content: data.content,
      created_at: msg.created_at,
    });
  }
}
