"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.OfflineSyncModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const offline_queue_entity_1 = require("./entities/offline-queue.entity");
const offline_sync_service_1 = require("./offline-sync.service");
const offline_sync_controller_1 = require("./offline-sync.controller");
let OfflineSyncModule = class OfflineSyncModule {
};
exports.OfflineSyncModule = OfflineSyncModule;
exports.OfflineSyncModule = OfflineSyncModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([offline_queue_entity_1.OfflineQueue])],
        controllers: [offline_sync_controller_1.OfflineSyncController],
        providers: [offline_sync_service_1.OfflineSyncService],
        exports: [offline_sync_service_1.OfflineSyncService],
    })
], OfflineSyncModule);
//# sourceMappingURL=offline-sync.module.js.map