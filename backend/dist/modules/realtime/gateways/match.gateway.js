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
var MatchGateway_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.MatchGateway = void 0;
const websockets_1 = require("@nestjs/websockets");
const socket_io_1 = require("socket.io");
const common_1 = require("@nestjs/common");
let MatchGateway = MatchGateway_1 = class MatchGateway {
    constructor() {
        this.logger = new common_1.Logger(MatchGateway_1.name);
    }
    handleConnection(client) {
        this.logger.log(`Client connected: ${client.id}`);
    }
    handleDisconnect(client) {
        this.logger.log(`Client disconnected: ${client.id}`);
    }
    handleJoinMatch(client, data) {
        client.join(`match:${data.match_id}`);
        this.logger.log(`${client.id} joined match:${data.match_id}`);
        return { event: 'joined', match_id: data.match_id };
    }
    handleLeaveMatch(client, data) {
        client.leave(`match:${data.match_id}`);
    }
    handleThrow(client, data) {
        this.server.to(`match:${data.match_id}`).emit('throw_update', data);
    }
    handleScoreSync(client, data) {
        this.server.to(`match:${data.match_id}`).emit('score_sync', data);
    }
    emitMatchUpdate(matchId, payload) {
        this.server.to(`match:${matchId}`).emit('match_update', payload);
    }
    emitLegComplete(matchId, payload) {
        this.server.to(`match:${matchId}`).emit('leg_complete', payload);
    }
    emitMatchComplete(matchId, payload) {
        this.server.to(`match:${matchId}`).emit('match_complete', payload);
    }
};
exports.MatchGateway = MatchGateway;
__decorate([
    (0, websockets_1.WebSocketServer)(),
    __metadata("design:type", socket_io_1.Server)
], MatchGateway.prototype, "server", void 0);
__decorate([
    (0, websockets_1.SubscribeMessage)('join_match'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", void 0)
], MatchGateway.prototype, "handleJoinMatch", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('leave_match'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", void 0)
], MatchGateway.prototype, "handleLeaveMatch", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('throw_event'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", void 0)
], MatchGateway.prototype, "handleThrow", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('score_sync'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", void 0)
], MatchGateway.prototype, "handleScoreSync", null);
exports.MatchGateway = MatchGateway = MatchGateway_1 = __decorate([
    (0, websockets_1.WebSocketGateway)({ namespace: '/ws/match', cors: { origin: '*' } })
], MatchGateway);
//# sourceMappingURL=match.gateway.js.map