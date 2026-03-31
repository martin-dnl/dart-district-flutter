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
exports.SystemGateway = void 0;
const websockets_1 = require("@nestjs/websockets");
const socket_io_1 = require("socket.io");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const direct_message_entity_1 = require("../entities/direct-message.entity");
let SystemGateway = class SystemGateway {
    constructor(directMessageRepo) {
        this.directMessageRepo = directMessageRepo;
    }
    handleSubscribeUser(client, data) {
        client.join(`user:${data.user_id}`);
        return { event: 'subscribed_user' };
    }
    handleSubscribeClub(client, data) {
        client.join(`club:${data.club_id}`);
        return { event: 'subscribed_club' };
    }
    handleQrScan(client, data) {
        this.server.emit('qr_scan_event', data);
    }
    async handleDirectMessage(client, data) {
        const content = (data.content ?? '').trim();
        if (!data.from_user_id || !data.to_user_id || !content) {
            return { event: 'direct_message_ignored' };
        }
        const saved = await this.directMessageRepo.save(this.directMessageRepo.create({
            from_user_id: data.from_user_id,
            to_user_id: data.to_user_id,
            content,
            read_at: null,
        }));
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
    emitNotification(userId, payload) {
        this.server.to(`user:${userId}`).emit('notification', payload);
    }
    emitClubEvent(clubId, event, payload) {
        this.server.to(`club:${clubId}`).emit(event, payload);
    }
    emitSyncComplete(userId, payload) {
        this.server.to(`user:${userId}`).emit('sync_complete', payload);
    }
    emitUserEvent(userId, event, payload) {
        this.server.to(`user:${userId}`).emit(event, payload);
    }
};
exports.SystemGateway = SystemGateway;
__decorate([
    (0, websockets_1.WebSocketServer)(),
    __metadata("design:type", socket_io_1.Server)
], SystemGateway.prototype, "server", void 0);
__decorate([
    (0, websockets_1.SubscribeMessage)('subscribe_user'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", void 0)
], SystemGateway.prototype, "handleSubscribeUser", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('subscribe_club'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", void 0)
], SystemGateway.prototype, "handleSubscribeClub", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('qr_scan'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", void 0)
], SystemGateway.prototype, "handleQrScan", null);
__decorate([
    (0, websockets_1.SubscribeMessage)('direct_message'),
    __param(0, (0, websockets_1.ConnectedSocket)()),
    __param(1, (0, websockets_1.MessageBody)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [socket_io_1.Socket, Object]),
    __metadata("design:returntype", Promise)
], SystemGateway.prototype, "handleDirectMessage", null);
exports.SystemGateway = SystemGateway = __decorate([
    (0, websockets_1.WebSocketGateway)({ namespace: '/ws/system', cors: { origin: '*' } }),
    __param(0, (0, typeorm_1.InjectRepository)(direct_message_entity_1.DirectMessage)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], SystemGateway);
//# sourceMappingURL=system.gateway.js.map