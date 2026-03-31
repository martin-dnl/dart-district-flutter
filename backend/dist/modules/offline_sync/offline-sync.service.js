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
var OfflineSyncService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.OfflineSyncService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const offline_queue_entity_1 = require("./entities/offline-queue.entity");
let OfflineSyncService = OfflineSyncService_1 = class OfflineSyncService {
    constructor(queueRepo) {
        this.queueRepo = queueRepo;
        this.logger = new common_1.Logger(OfflineSyncService_1.name);
    }
    async push(userId, items) {
        const results = [];
        for (const item of items) {
            const entry = this.queueRepo.create({
                user: { id: userId },
                user_id: userId,
                entity_type: item.entity_type,
                entity_id: item.entity_id ?? null,
                action: item.action,
                payload: item.payload,
                client_ts: new Date(),
            });
            if (item.entity_id) {
                const conflict = await this.queueRepo.findOne({
                    where: {
                        entity_type: item.entity_type,
                        entity_id: item.entity_id,
                        processed: false,
                    },
                });
                if (conflict && conflict.user_id !== userId) {
                    entry.conflict = true;
                    entry.conflict_detail = JSON.stringify(conflict.payload);
                    this.logger.warn(`Conflict detected: ${item.entity_type}/${item.entity_id}`);
                }
            }
            const saved = await this.queueRepo.save(entry);
            results.push({
                id: saved.id,
                status: saved.conflict ? 'conflict' : 'queued',
                conflict: saved.conflict,
            });
        }
        return results;
    }
    async pull(userId, since) {
        const qb = this.queueRepo
            .createQueryBuilder('q')
            .where('q.user_id = :userId', { userId })
            .andWhere('q.processed = false');
        if (since) {
            qb.andWhere('q.created_at > :since', { since });
        }
        const items = await qb.orderBy('q.created_at', 'ASC').getMany();
        const ids = items.map((i) => i.id);
        if (ids.length > 0) {
            await this.queueRepo
                .createQueryBuilder()
                .update()
                .set({ processed: true, processed_at: new Date() })
                .whereInIds(ids)
                .execute();
        }
        return items;
    }
    async resolveConflict(entryId, resolution) {
        const entry = await this.queueRepo.findOne({ where: { id: entryId } });
        if (!entry)
            return null;
        if (resolution === 'keep_local') {
            entry.conflict = false;
            entry.conflict_detail = null;
        }
        else {
            entry.processed = true;
            entry.processed_at = new Date();
            entry.conflict = false;
        }
        return this.queueRepo.save(entry);
    }
};
exports.OfflineSyncService = OfflineSyncService;
exports.OfflineSyncService = OfflineSyncService = OfflineSyncService_1 = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(offline_queue_entity_1.OfflineQueue)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], OfflineSyncService);
//# sourceMappingURL=offline-sync.service.js.map