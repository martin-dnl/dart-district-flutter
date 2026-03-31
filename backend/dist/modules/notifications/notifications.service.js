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
exports.NotificationsService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const notification_entity_1 = require("./entities/notification.entity");
const normalize_limit_1 = require("../../common/utils/normalize-limit");
let NotificationsService = class NotificationsService {
    constructor(repo) {
        this.repo = repo;
    }
    async findByUser(userId, limit = 50) {
        const take = (0, normalize_limit_1.normalizeLimit)(limit, 50);
        return this.repo.find({
            where: { user: { id: userId } },
            order: { created_at: 'DESC' },
            take,
        });
    }
    async create(userId, type, data) {
        const n = this.repo.create({
            user: { id: userId },
            type: type,
            data,
        });
        return this.repo.save(n);
    }
    async markRead(id, userId) {
        const n = await this.repo.findOne({
            where: { id, user: { id: userId } },
        });
        if (!n)
            throw new common_1.NotFoundException('Notification not found');
        n.is_read = true;
        return this.repo.save(n);
    }
    async markAllRead(userId) {
        await this.repo.update({ user: { id: userId }, is_read: false }, { is_read: true });
    }
    async unreadCount(userId) {
        return this.repo.count({
            where: { user: { id: userId }, is_read: false },
        });
    }
};
exports.NotificationsService = NotificationsService;
exports.NotificationsService = NotificationsService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(notification_entity_1.Notification)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], NotificationsService);
//# sourceMappingURL=notifications.service.js.map