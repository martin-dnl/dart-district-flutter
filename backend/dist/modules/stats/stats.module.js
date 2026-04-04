"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.StatsModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const player_stat_entity_1 = require("./entities/player-stat.entity");
const elo_history_entity_1 = require("./entities/elo-history.entity");
const user_entity_1 = require("../users/entities/user.entity");
const stats_service_1 = require("./stats.service");
const stats_controller_1 = require("./stats.controller");
const throw_entity_1 = require("../matches/entities/throw.entity");
let StatsModule = class StatsModule {
};
exports.StatsModule = StatsModule;
exports.StatsModule = StatsModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([player_stat_entity_1.PlayerStat, elo_history_entity_1.EloHistory, user_entity_1.User, throw_entity_1.Throw])],
        controllers: [stats_controller_1.StatsController],
        providers: [stats_service_1.StatsService],
        exports: [stats_service_1.StatsService],
    })
], StatsModule);
//# sourceMappingURL=stats.module.js.map