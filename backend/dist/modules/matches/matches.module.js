"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MatchesModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const match_entity_1 = require("./entities/match.entity");
const match_player_entity_1 = require("./entities/match-player.entity");
const set_entity_1 = require("./entities/set.entity");
const leg_entity_1 = require("./entities/leg.entity");
const throw_entity_1 = require("./entities/throw.entity");
const matches_service_1 = require("./matches.service");
const matches_controller_1 = require("./matches.controller");
const realtime_module_1 = require("../realtime/realtime.module");
const stats_module_1 = require("../stats/stats.module");
const territory_entity_1 = require("../territories/entities/territory.entity");
let MatchesModule = class MatchesModule {
};
exports.MatchesModule = MatchesModule;
exports.MatchesModule = MatchesModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([match_entity_1.Match, match_player_entity_1.MatchPlayer, set_entity_1.Set, leg_entity_1.Leg, throw_entity_1.Throw, territory_entity_1.Territory]),
            realtime_module_1.RealtimeModule,
            stats_module_1.StatsModule,
        ],
        controllers: [matches_controller_1.MatchesController],
        providers: [matches_service_1.MatchesService],
        exports: [matches_service_1.MatchesService],
    })
], MatchesModule);
//# sourceMappingURL=matches.module.js.map