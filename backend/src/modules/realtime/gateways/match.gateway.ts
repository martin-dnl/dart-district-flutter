import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';

@WebSocketGateway({ namespace: '/ws/match', cors: { origin: '*' } })
export class MatchGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;
  private readonly logger = new Logger(MatchGateway.name);

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('join_match')
  handleJoinMatch(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { match_id: string },
  ) {
    client.join(`match:${data.match_id}`);
    this.logger.log(`${client.id} joined match:${data.match_id}`);
    return { event: 'joined', match_id: data.match_id };
  }

  @SubscribeMessage('leave_match')
  handleLeaveMatch(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { match_id: string },
  ) {
    client.leave(`match:${data.match_id}`);
  }

  @SubscribeMessage('throw_event')
  handleThrow(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { match_id: string; leg_id: string; player_id: string; segment: string; score: number; remaining: number },
  ) {
    // Broadcast to all clients in the match room
    this.server.to(`match:${data.match_id}`).emit('throw_update', data);
  }

  @SubscribeMessage('score_sync')
  handleScoreSync(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { match_id: string; scores: Record<string, number> },
  ) {
    this.server.to(`match:${data.match_id}`).emit('score_sync', data);
  }

  // Server-side emit helpers
  emitMatchUpdate(matchId: string, payload: unknown) {
    this.server.to(`match:${matchId}`).emit('match_update', payload);
  }

  emitLegComplete(matchId: string, payload: unknown) {
    this.server.to(`match:${matchId}`).emit('leg_complete', payload);
  }

  emitMatchComplete(matchId: string, payload: unknown) {
    this.server.to(`match:${matchId}`).emit('match_complete', payload);
  }
}
