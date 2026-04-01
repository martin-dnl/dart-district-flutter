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
  private readonly rolesBySocket = new Map<string, string>();

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.rolesBySocket.delete(client.id);
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('join_match')
  handleJoinMatch(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { match_id: string; role?: string },
  ) {
    const role = (data.role ?? 'player').toLowerCase();
    const allowedRole = role === 'spectator' ? 'spectator' : 'player';
    this.rolesBySocket.set(client.id, allowedRole);
    client.join(`match:${data.match_id}`);
    this.logger.log(
      `${client.id} joined match:${data.match_id} as ${allowedRole}`,
    );
    return { event: 'joined', match_id: data.match_id, role: allowedRole };
  }

  @SubscribeMessage('leave_match')
  handleLeaveMatch(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { match_id: string },
  ) {
    this.rolesBySocket.delete(client.id);
    client.leave(`match:${data.match_id}`);
  }

  @SubscribeMessage('throw_event')
  handleThrow(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { match_id: string; leg_id: string; player_id: string; segment: string; score: number; remaining: number },
  ) {
    if (this.rolesBySocket.get(client.id) === 'spectator') {
      return { error: 'Spectators cannot submit throw events' };
    }
    // Broadcast to all clients in the match room
    this.server.to(`match:${data.match_id}`).emit('throw_update', data);
  }

  @SubscribeMessage('score_sync')
  handleScoreSync(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { match_id: string; scores: Record<string, number> },
  ) {
    if (this.rolesBySocket.get(client.id) === 'spectator') {
      return { error: 'Spectators cannot submit score events' };
    }
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
