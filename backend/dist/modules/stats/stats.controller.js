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
exports.StatsController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const stats_service_1 = require("./stats.service");
const jwt_auth_guard_1 = require("../auth/guards/jwt-auth.guard");
let StatsController = class StatsController {
    constructor(statsService) {
        this.statsService = statsService;
    }
    myStats(req) {
        return this.statsService.getByUser(req.user.id);
    }
    myEloHistory(req, limit, mode, offset) {
        if (mode) {
            return this.statsService.eloHistoryByPeriod(req.user.id, mode, offset);
        }
        return this.statsService.eloHistory(req.user.id, limit);
    }
    myDartboardPeriods(req) {
        return this.statsService.getDartboardPeriods(req.user.id);
    }
    myDartboardHeatmap(req, period, year, month) {
        return this.statsService.getDartboardHeatmap(req.user.id, {
            period,
            year,
            month,
        });
    }
    userStats(userId) {
        return this.statsService.getByUser(userId);
    }
    userEloHistory(userId, limit, mode, offset) {
        if (mode) {
            return this.statsService.eloHistoryByPeriod(userId, mode, offset);
        }
        return this.statsService.eloHistory(userId, limit);
    }
    userDartboardPeriods(userId) {
        return this.statsService.getDartboardPeriods(userId);
    }
    userDartboardHeatmap(userId, period, year, month) {
        return this.statsService.getDartboardHeatmap(userId, {
            period,
            year,
            month,
        });
    }
};
exports.StatsController = StatsController;
__decorate([
    (0, common_1.Get)('me'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], StatsController.prototype, "myStats", null);
__decorate([
    (0, common_1.Get)('me/elo-history'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Query)('limit')),
    __param(2, (0, common_1.Query)('mode')),
    __param(3, (0, common_1.Query)('offset')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Number, String, Number]),
    __metadata("design:returntype", void 0)
], StatsController.prototype, "myEloHistory", null);
__decorate([
    (0, common_1.Get)('me/dartboard-periods'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], StatsController.prototype, "myDartboardPeriods", null);
__decorate([
    (0, common_1.Get)('me/dartboard-heatmap'),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Query)('period')),
    __param(2, (0, common_1.Query)('year')),
    __param(3, (0, common_1.Query)('month')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, Number, Number]),
    __metadata("design:returntype", void 0)
], StatsController.prototype, "myDartboardHeatmap", null);
__decorate([
    (0, common_1.Get)(':userId'),
    __param(0, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], StatsController.prototype, "userStats", null);
__decorate([
    (0, common_1.Get)(':userId/elo-history'),
    __param(0, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('limit')),
    __param(2, (0, common_1.Query)('mode')),
    __param(3, (0, common_1.Query)('offset')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Number, String, Number]),
    __metadata("design:returntype", void 0)
], StatsController.prototype, "userEloHistory", null);
__decorate([
    (0, common_1.Get)(':userId/dartboard-periods'),
    __param(0, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], StatsController.prototype, "userDartboardPeriods", null);
__decorate([
    (0, common_1.Get)(':userId/dartboard-heatmap'),
    __param(0, (0, common_1.Param)('userId', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('period')),
    __param(2, (0, common_1.Query)('year')),
    __param(3, (0, common_1.Query)('month')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, Number, Number]),
    __metadata("design:returntype", void 0)
], StatsController.prototype, "userDartboardHeatmap", null);
exports.StatsController = StatsController = __decorate([
    (0, swagger_1.ApiTags)('stats'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('stats'),
    __metadata("design:paramtypes", [stats_service_1.StatsService])
], StatsController);
//# sourceMappingURL=stats.controller.js.map