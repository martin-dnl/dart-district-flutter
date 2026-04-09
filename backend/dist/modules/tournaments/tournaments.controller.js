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
exports.TournamentsController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const tournaments_service_1 = require("./tournaments.service");
const create_tournament_dto_1 = require("./dto/create-tournament.dto");
const jwt_auth_guard_1 = require("../auth/guards/jwt-auth.guard");
const disqualify_player_dto_1 = require("./dto/disqualify-player.dto");
let TournamentsController = class TournamentsController {
    constructor(tournamentsService) {
        this.tournamentsService = tournamentsService;
    }
    create(dto, req) {
        if (req.user.is_guest || req.user.id === 'guest') {
            throw new common_1.ForbiddenException('Guest account cannot create tournaments');
        }
        if (dto.club_id && req.user.is_admin !== true) {
            return this.tournamentsService
                .canCreateForClub(req.user.id, dto.club_id)
                .then((canCreate) => {
                if (!canCreate) {
                    throw new common_1.ForbiddenException('Only an admin or the club president can create a club tournament');
                }
                return this.tournamentsService.create(dto, req.user.id);
            });
        }
        return this.tournamentsService.create(dto, req.user.id);
    }
    findAll(status, upcoming, clubId) {
        return this.tournamentsService.findAll({ status, upcoming, clubId });
    }
    findOne(id) {
        return this.tournamentsService.findById(id);
    }
    register(id, req) {
        if (req.user.is_guest || req.user.id === 'guest') {
            throw new common_1.ForbiddenException('Guest account cannot register to tournaments');
        }
        return this.tournamentsService.registerPlayer(id, req.user.id);
    }
    unregister(id, req) {
        return this.tournamentsService.unregisterPlayer(id, req.user.id);
    }
    generatePools(id, req) {
        return this.tournamentsService.generatePools(id, req.user.id);
    }
    getPools(id) {
        return this.tournamentsService.getPools(id);
    }
    getPoolStandings(poolId) {
        return this.tournamentsService.getPoolStandings(poolId);
    }
    generateBracket(id, req) {
        return this.tournamentsService.generateBracket(id, req.user.id);
    }
    getBracket(id) {
        return this.tournamentsService.getBracket(id);
    }
    advancePhase(id, req) {
        return this.tournamentsService.advancePhase(id, req.user.id);
    }
    disqualify(id, playerId, dto, req) {
        return this.tournamentsService.disqualifyPlayer(id, playerId, dto.reason, req.user.id);
    }
};
exports.TournamentsController = TournamentsController;
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_tournament_dto_1.CreateTournamentDto, Object]),
    __metadata("design:returntype", void 0)
], TournamentsController.prototype, "create", null);
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('status')),
    __param(1, (0, common_1.Query)('upcoming')),
    __param(2, (0, common_1.Query)('club_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String]),
    __metadata("design:returntype", void 0)
], TournamentsController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TournamentsController.prototype, "findOne", null);
__decorate([
    (0, common_1.Post)(':id/register'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], TournamentsController.prototype, "register", null);
__decorate([
    (0, common_1.Delete)(':id/register'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], TournamentsController.prototype, "unregister", null);
__decorate([
    (0, common_1.Post)(':id/pools'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], TournamentsController.prototype, "generatePools", null);
__decorate([
    (0, common_1.Get)(':id/pools'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TournamentsController.prototype, "getPools", null);
__decorate([
    (0, common_1.Get)(':id/pools/:poolId/standings'),
    __param(0, (0, common_1.Param)('poolId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TournamentsController.prototype, "getPoolStandings", null);
__decorate([
    (0, common_1.Post)(':id/bracket'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], TournamentsController.prototype, "generateBracket", null);
__decorate([
    (0, common_1.Get)(':id/bracket'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], TournamentsController.prototype, "getBracket", null);
__decorate([
    (0, common_1.Post)(':id/advance'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], TournamentsController.prototype, "advancePhase", null);
__decorate([
    (0, common_1.Post)(':id/disqualify/:playerId'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Param)('playerId', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, disqualify_player_dto_1.DisqualifyPlayerDto, Object]),
    __metadata("design:returntype", void 0)
], TournamentsController.prototype, "disqualify", null);
exports.TournamentsController = TournamentsController = __decorate([
    (0, swagger_1.ApiTags)('tournaments'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('tournaments'),
    __metadata("design:paramtypes", [tournaments_service_1.TournamentsService])
], TournamentsController);
//# sourceMappingURL=tournaments.controller.js.map