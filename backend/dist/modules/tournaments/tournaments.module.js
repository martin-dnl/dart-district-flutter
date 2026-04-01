"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.TournamentsModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const tournament_entity_1 = require("./entities/tournament.entity");
const tournament_player_entity_1 = require("./entities/tournament-player.entity");
const tournament_pool_entity_1 = require("./entities/tournament-pool.entity");
const tournament_pool_standing_entity_1 = require("./entities/tournament-pool-standing.entity");
const tournament_bracket_match_entity_1 = require("./entities/tournament-bracket-match.entity");
const tournaments_service_1 = require("./tournaments.service");
const tournaments_controller_1 = require("./tournaments.controller");
let TournamentsModule = class TournamentsModule {
};
exports.TournamentsModule = TournamentsModule;
exports.TournamentsModule = TournamentsModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([
                tournament_entity_1.Tournament,
                tournament_player_entity_1.TournamentPlayer,
                tournament_pool_entity_1.TournamentPool,
                tournament_pool_standing_entity_1.TournamentPoolStanding,
                tournament_bracket_match_entity_1.TournamentBracketMatch,
            ]),
        ],
        controllers: [tournaments_controller_1.TournamentsController],
        providers: [tournaments_service_1.TournamentsService],
        exports: [tournaments_service_1.TournamentsService],
    })
], TournamentsModule);
//# sourceMappingURL=tournaments.module.js.map