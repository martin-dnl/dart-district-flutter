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
exports.TerritoriesController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const territories_service_1 = require("./territories.service");
const create_duel_dto_1 = require("./dto/create-duel.dto");
const jwt_auth_guard_1 = require("../auth/guards/jwt-auth.guard");
const query_territory_statuses_dto_1 = require("./dto/query-territory-statuses.dto");
const update_territory_status_dto_1 = require("./dto/update-territory-status.dto");
const update_territory_owner_dto_1 = require("./dto/update-territory-owner.dto");
let TerritoriesController = class TerritoriesController {
    constructor(territoriesService) {
        this.territoriesService = territoriesService;
    }
    tilesetMetadata() {
        return this.territoriesService.getTilesetMetadata();
    }
    mapStatuses(query) {
        return this.territoriesService.getMapStatuses(query);
    }
    getMapData() {
        return this.territoriesService.getMapData();
    }
    mapHit(latRaw, lngRaw, zoomRaw, viewportWidthRaw) {
        const lat = Number.parseFloat(latRaw);
        const lng = Number.parseFloat(lngRaw);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
            throw new common_1.BadRequestException('lat and lng query params are required numbers');
        }
        const zoom = zoomRaw == null ? undefined : Number.parseFloat(zoomRaw);
        const viewportWidthPx = viewportWidthRaw == null ? undefined : Number.parseFloat(viewportWidthRaw);
        if (zoomRaw != null && !Number.isFinite(zoom)) {
            throw new common_1.BadRequestException('zoom query param must be a valid number');
        }
        if (viewportWidthRaw != null && !Number.isFinite(viewportWidthPx)) {
            throw new common_1.BadRequestException('viewport_width_px query param must be a valid number');
        }
        return this.territoriesService.hitTestByCoordinates(lat, lng, zoom, viewportWidthPx);
    }
    findAll() {
        return this.territoriesService.findAll();
    }
    findOne(codeIris) {
        return this.territoriesService.findByCodeIris(codeIris);
    }
    panel(codeIris) {
        return this.territoriesService.getTerritoryPanel(codeIris);
    }
    history(codeIris) {
        return this.territoriesService.history(codeIris);
    }
    updateStatus(codeIris, dto, req) {
        return this.territoriesService.updateStatus(codeIris, dto, req.user.id);
    }
    updateOwner(codeIris, dto) {
        return this.territoriesService.transferOwnership(codeIris, dto.winner_club_id ?? dto.owner_club_id ?? null, dto.event ?? 'manual_transfer');
    }
    createDuel(dto, req) {
        return this.territoriesService.createDuel(dto, req.user.id);
    }
    pendingDuels(req) {
        return this.territoriesService.findPendingDuelsForUser(req.user.id);
    }
    acceptDuel(id) {
        return this.territoriesService.acceptDuel(id);
    }
    completeDuel(id, winnerClubId) {
        return this.territoriesService.completeDuel(id, winnerClubId);
    }
};
exports.TerritoriesController = TerritoriesController;
__decorate([
    (0, common_1.Get)('tileset'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], TerritoriesController.prototype, "tilesetMetadata", null);
__decorate([
    (0, common_1.Get)('map/statuses'),
    __param(0, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [query_territory_statuses_dto_1.QueryTerritoryStatusesDto]),
    __metadata("design:returntype", void 0)
], TerritoriesController.prototype, "mapStatuses", null);
__decorate([
    (0, common_1.Get)('map/data'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], TerritoriesController.prototype, "getMapData", null);
__decorate([
    (0, common_1.Get)('map/hit'),
    __param(0, (0, common_1.Query)('lat')),
    __param(1, (0, common_1.Query)('lng')),
    __param(2, (0, common_1.Query)('zoom')),
    __param(3, (0, common_1.Query)('viewport_width_px')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, String]),
    __metadata("design:returntype", void 0)
], TerritoriesController.prototype, "mapHit", null);
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], TerritoriesController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)(':codeIris'),
    __param(0, (0, common_1.Param)('codeIris')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TerritoriesController.prototype, "findOne", null);
__decorate([
    (0, common_1.Get)(':codeIris/panel'),
    __param(0, (0, common_1.Param)('codeIris')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TerritoriesController.prototype, "panel", null);
__decorate([
    (0, common_1.Get)(':codeIris/history'),
    __param(0, (0, common_1.Param)('codeIris')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TerritoriesController.prototype, "history", null);
__decorate([
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Patch)(':codeIris/status'),
    __param(0, (0, common_1.Param)('codeIris')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_territory_status_dto_1.UpdateTerritoryStatusDto, Object]),
    __metadata("design:returntype", void 0)
], TerritoriesController.prototype, "updateStatus", null);
__decorate([
    (0, common_1.Patch)(':codeIris/owner'),
    __param(0, (0, common_1.Param)('codeIris')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_territory_owner_dto_1.UpdateTerritoryOwnerDto]),
    __metadata("design:returntype", void 0)
], TerritoriesController.prototype, "updateOwner", null);
__decorate([
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Post)('duels'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_duel_dto_1.CreateDuelDto, Object]),
    __metadata("design:returntype", void 0)
], TerritoriesController.prototype, "createDuel", null);
__decorate([
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Get)('duels/pending'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], TerritoriesController.prototype, "pendingDuels", null);
__decorate([
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Patch)('duels/:id/accept'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TerritoriesController.prototype, "acceptDuel", null);
__decorate([
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Patch)('duels/:id/complete'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)('winner_club_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", void 0)
], TerritoriesController.prototype, "completeDuel", null);
exports.TerritoriesController = TerritoriesController = __decorate([
    (0, swagger_1.ApiTags)('territories'),
    (0, common_1.Controller)('territories'),
    __metadata("design:paramtypes", [territories_service_1.TerritoriesService])
], TerritoriesController);
//# sourceMappingURL=territories.controller.js.map