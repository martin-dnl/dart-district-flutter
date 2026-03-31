import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';

@WebSocketGateway({ namespace: '/ws/territory', cors: { origin: '*' } })
export class TerritoryGateway {
  @WebSocketServer() server: Server;

  private normalizeTerritoryRoom(territoryId?: string, codeIris?: string): string {
    const code = (codeIris ?? territoryId ?? '').trim().toUpperCase();
    return `territory:${code}`;
  }

  @SubscribeMessage('subscribe_territory')
  handleSubscribe(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { territory_id?: string; code_iris?: string },
  ) {
    const room = this.normalizeTerritoryRoom(data.territory_id, data.code_iris);
    const codeIris = room.replace('territory:', '');
    client.join(room);
    return { event: 'subscribed', code_iris: codeIris };
  }

  @SubscribeMessage('subscribe_map')
  handleSubscribeMap(@ConnectedSocket() client: Socket) {
    client.join('territory:map');
    return { event: 'subscribed_map' };
  }

  // Server-side emit helpers
  emitTerritoryUpdate(codeIris: string, payload: unknown) {
    const room = this.normalizeTerritoryRoom(undefined, codeIris);
    this.server.to(room).emit('territory_update', payload);
    this.server.to('territory:map').emit('map_update', payload);
  }

  emitTerritoryStatusUpdated(codeIris: string, payload: unknown) {
    const room = this.normalizeTerritoryRoom(undefined, codeIris);
    this.server.to(room).emit('territory_status_updated', payload);
    this.server.to('territory:map').emit('territory_status_updated', payload);
  }

  emitTerritoryOwnerUpdated(codeIris: string, payload: unknown) {
    const room = this.normalizeTerritoryRoom(undefined, codeIris);
    this.server.to(room).emit('territory_owner_updated', payload);
    this.server.to('territory:map').emit('territory_owner_updated', payload);
  }

  emitDuelRequest(codeIris: string, payload: unknown) {
    const room = this.normalizeTerritoryRoom(undefined, codeIris);
    this.server.to(room).emit('duel_request', payload);
  }

  emitDuelAccepted(codeIris: string, payload: unknown) {
    const room = this.normalizeTerritoryRoom(undefined, codeIris);
    this.server.to(room).emit('duel_accepted', payload);
  }

  emitDuelCompleted(codeIris: string, payload: unknown) {
    const room = this.normalizeTerritoryRoom(undefined, codeIris);
    this.server.to(room).emit('duel_completed', payload);
    this.server.to('territory:map').emit('map_update', payload);
  }
}
