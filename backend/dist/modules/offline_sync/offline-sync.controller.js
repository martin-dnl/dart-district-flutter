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
exports.OfflineSyncController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const offline_sync_service_1 = require("./offline-sync.service");
const jwt_auth_guard_1 = require("../auth/guards/jwt-auth.guard");
let OfflineSyncController = class OfflineSyncController {
    constructor(syncService) {
        this.syncService = syncService;
    }
    push(req, items) {
        return this.syncService.push(req.user.id, items);
    }
    pull(req, since) {
        return this.syncService.pull(req.user.id, since);
    }
    resolve(id, resolution) {
        return this.syncService.resolveConflict(id, resolution);
    }
};
exports.OfflineSyncController = OfflineSyncController;
__decorate([
    (0, common_1.Post)('push'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Array]),
    __metadata("design:returntype", void 0)
], OfflineSyncController.prototype, "push", null);
__decorate([
    (0, common_1.Get)('pull'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Query)('since')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], OfflineSyncController.prototype, "pull", null);
__decorate([
    (0, common_1.Patch)(':id/resolve'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)('resolution')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", void 0)
], OfflineSyncController.prototype, "resolve", null);
exports.OfflineSyncController = OfflineSyncController = __decorate([
    (0, swagger_1.ApiTags)('offline-sync'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('sync'),
    __metadata("design:paramtypes", [offline_sync_service_1.OfflineSyncService])
], OfflineSyncController);
//# sourceMappingURL=offline-sync.controller.js.map