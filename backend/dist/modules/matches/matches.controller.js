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
exports.MatchesController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const matches_service_1 = require("./matches.service");
const create_match_dto_1 = require("./dto/create-match.dto");
const submit_throw_dto_1 = require("./dto/submit-throw.dto");
const jwt_auth_guard_1 = require("../auth/guards/jwt-auth.guard");
let MatchesController = class MatchesController {
    constructor(matchesService) {
        this.matchesService = matchesService;
    }
    createInvitation(body, req) {
        return this.matchesService.createInvitation(req.user.id, body);
    }
    ongoing(req) {
        return this.matchesService.getOngoingForUser(req.user.id);
    }
    acceptInvitation(id, req) {
        return this.matchesService.acceptInvitation(id, req.user.id);
    }
    refuseInvitation(id, req) {
        return this.matchesService.refuseInvitation(id, req.user.id);
    }
    cancelInvitation(id, req) {
        return this.matchesService.cancelInvitation(id, req.user.id);
    }
    submitScore(id, body, req) {
        return this.matchesService.submitScore(id, req.user.id, body);
    }
    undoLastThrow(id, req) {
        return this.matchesService.undoLastThrow(id, req.user.id);
    }
    abandonMatch(id, body, req) {
        return this.matchesService.abandonMatch(id, req.user.id, body);
    }
    create(dto) {
        return this.matchesService.create(dto);
    }
    myMatches(req, limit, offset, status, ranked) {
        return this.matchesService.findByUser(req.user.id, limit, offset, status, ranked);
    }
    report(id) {
        return this.matchesService.getMatchReport(id);
    }
    findOne(id) {
        return this.matchesService.findById(id);
    }
    submitThrow(matchId, legId, dto, req) {
        return this.matchesService.submitThrow(matchId, legId, req.user.id, dto);
    }
    validate(id, req) {
        return this.matchesService.validateMatch(id, req.user.id);
    }
};
exports.MatchesController = MatchesController;
__decorate([
    (0, common_1.Post)('invitation'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", void 0)
], MatchesController.prototype, "createInvitation", null);
__decorate([
    (0, common_1.Get)('ongoing'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], MatchesController.prototype, "ongoing", null);
__decorate([
    (0, common_1.Post)(':id/accept'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], MatchesController.prototype, "acceptInvitation", null);
__decorate([
    (0, common_1.Post)(':id/refuse'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], MatchesController.prototype, "refuseInvitation", null);
__decorate([
    (0, common_1.Post)(':id/cancel'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], MatchesController.prototype, "cancelInvitation", null);
__decorate([
    (0, common_1.Post)(':id/score'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", void 0)
], MatchesController.prototype, "submitScore", null);
__decorate([
    (0, common_1.Post)(':id/undo'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], MatchesController.prototype, "undoLastThrow", null);
__decorate([
    (0, common_1.Post)(':id/abandon'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", void 0)
], MatchesController.prototype, "abandonMatch", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_match_dto_1.CreateMatchDto]),
    __metadata("design:returntype", void 0)
], MatchesController.prototype, "create", null);
__decorate([
    (0, common_1.Get)('me'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Query)('limit')),
    __param(2, (0, common_1.Query)('offset')),
    __param(3, (0, common_1.Query)('status')),
    __param(4, (0, common_1.Query)('ranked')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Number, Number, String, String]),
    __metadata("design:returntype", void 0)
], MatchesController.prototype, "myMatches", null);
__decorate([
    (0, common_1.Get)(':id/report'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], MatchesController.prototype, "report", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], MatchesController.prototype, "findOne", null);
__decorate([
    (0, common_1.Post)(':id/legs/:legId/throws'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Param)('legId', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, submit_throw_dto_1.SubmitThrowDto, Object]),
    __metadata("design:returntype", void 0)
], MatchesController.prototype, "submitThrow", null);
__decorate([
    (0, common_1.Patch)(':id/validate'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object]),
    __metadata("design:returntype", void 0)
], MatchesController.prototype, "validate", null);
exports.MatchesController = MatchesController = __decorate([
    (0, swagger_1.ApiTags)('matches'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('matches'),
    __metadata("design:paramtypes", [matches_service_1.MatchesService])
], MatchesController);
//# sourceMappingURL=matches.controller.js.map