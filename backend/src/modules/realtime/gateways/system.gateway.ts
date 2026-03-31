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
import { DirectMessage } from '../entities/direct-message.entity';

@WebSocketGateway({ namespace: '/ws/system', cors: { origin: '*' } })
export class SystemGateway {
  @WebSocketServer() server: Server;

  constructor(
    @InjectRepository(DirectMessage)
    private readonly directMessageRepo: Repository<DirectMessage>,
  ) {}

  @SubscribeMessage('subscribe_user')
  handleSubscribeUser(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { user_id: string },
  ) {
    client.join(`user:${data.user_id}`);
    return { event: 'subscribed_user' };
  }

  @SubscribeMessage('subscribe_club')
  handleSubscribeClub(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { club_id: string },
  ) {
    client.join(`club:${data.club_id}`);
    return { event: 'subscribed_club' };
  }

  @SubscribeMessage('qr_scan')
  handleQrScan(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { qr_code: string; user_id: string },
  ) {
    // Broadcast scan event so connected clients can react
    this.server.emit('qr_scan_event', data);
  }

  @SubscribeMessage('direct_message')
  async handleDirectMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: { from_user_id: string; to_user_id: string; content: string },
  ) {
    const content = (data.content ?? '').trim();
    if (!data.from_user_id || !data.to_user_id || !content) {
      return { event: 'direct_message_ignored' };
    }

    const saved = await this.directMessageRepo.save(
      this.directMessageRepo.create({
        from_user_id: data.from_user_id,
        to_user_id: data.to_user_id,
        content,
        read_at: null,
      }),
    );

    const payload = {
      id: saved.id,
      from_user_id: data.from_user_id,
      to_user_id: data.to_user_id,
      content: saved.content,
      created_at: saved.created_at,
      read_at: saved.read_at,
    };

    this.server.to(`user:${data.to_user_id}`).emit('direct_message', payload);
    this.server.to(`user:${data.from_user_id}`).emit('direct_message', payload);

    return { event: 'direct_message_sent' };
  }

  // Server-side emit helpers
  emitNotification(userId: string, payload: unknown) {
    this.server.to(`user:${userId}`).emit('notification', payload);
  }

  emitClubEvent(clubId: string, event: string, payload: unknown) {
    this.server.to(`club:${clubId}`).emit(event, payload);
  }

  emitSyncComplete(userId: string, payload: unknown) {
    this.server.to(`user:${userId}`).emit('sync_complete', payload);
  }

  emitUserEvent(userId: string, event: string, payload: unknown) {
    this.server.to(`user:${userId}`).emit(event, payload);
  }
}
