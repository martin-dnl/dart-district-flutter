"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.TerritoryGateway = void 0;
const websockets_1 = require("@nestjs/websockets");
const socket_io_1 = require("socket.io");
let TerritoryGateway = class TerritoryGateway {
    normalizeTerritoryRoom(territoryId, codeIris) {
        const code = (codeIris ?? territoryId ?? '').trim().toUpperCase();
        return `territory:${code}`;
    }
    handleSubscribe(client, data) {
        const room = this.normalizeTerritoryRoom(data.territory_id, data.code_iris);
        const codeIris = room.replace('territory:', '');
        client.join(room);
        return { event: 'subscribed', code_iris: codeIris };
    }
    handleSubscribeMap(client) {
        client.join('territory:map');
        return { event: 'subscribed_map' };
    }
    emitTerritoryUpdate(codeIris, payload) {
        const room = this.normalizeTerritoryRoom(undefined, codeIris);
        this.server.to(room).emit('territory_update', payload);
        this.server.to('territory:map').emit('map_update', payload);
    }
    emitTerritoryStatusUpdated(codeIris, payload) {
        const room = this.normalizeTerritoryRoom(undefined, codeIris);
        this.server.to(room).emit('territory_status_updated', payload);
        this.server.to('territory:map').emit('territory_status_updated', payload);
    }
    emitTerritoryOwnerUpdated(codeIris, payload) {
        const room = this.normalizeTerritoryRoom(undefined, codeIris);
        this.server.to(room).emit('territory_owner_updated', payload);
        this.server.to('territory:map').emit('territory_owner_updated', payload);
    }
    emitDuelRequest(codeIris, payload) {
        const room = this.normalizeTerritoryRoom(undefined, codeIris);
        this.server.to(room).emit('duel_request', payload);
    }
    emitDuelAccepted(codeIris, payload) {
        const room = this.normalizeTerritoryRoom(undefined, codeIris);
        this.server.to(room).emit('duel_accepted', payload);
    }
    emitDuelCompleted(codeIris, payload) {
        const room = this.normalizeTerritoryRoom(undefined, codeIris);
        this.server.to(room).emit('duel_completed', payload);
        this.server.to('territory:map').emit('map_update', payload);
    }
};
exports.TerritoryGateway = TerritoryGateway;
__decorate([
    (0, websockets_1.WebSocketServer)(),
    __metadata("design:type", socket_io_1.Server)
], TerritoryGateway.prototype, "server", void 0);
__decorate([
    (0, websockets_1.SubscribeMessage)('subscribe_territory'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", void 0)
], TerritoryGateway.prototype, "handleSubscribe", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('subscribe_map'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket]),
    __metadata("design:returntype", void 0)
], TerritoryGateway.prototype, "handleSubscribeMap", null);
exports.TerritoryGateway = TerritoryGateway = __decorate([
    (0, websockets_1.WebSocketGateway)({ namespace: '/ws/territory', cors: { origin: '*' } })
], TerritoryGateway);
//# sourceMappingURL=territory.gateway.js.map