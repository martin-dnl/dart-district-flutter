"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.TerritoriesModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const territory_entity_1 = require("./entities/territory.entity");
const territory_history_entity_1 = require("./entities/territory-history.entity");
const duel_entity_1 = require("./entities/duel.entity");
const territory_tileset_entity_1 = require("./entities/territory-tileset.entity");
const territories_service_1 = require("./territories.service");
const territories_controller_1 = require("./territories.controller");
const club_member_entity_1 = require("../clubs/entities/club-member.entity");
const realtime_module_1 = require("../realtime/realtime.module");
let TerritoriesModule = class TerritoriesModule {
};
exports.TerritoriesModule = TerritoriesModule;
exports.TerritoriesModule = TerritoriesModule = __decorate([
    (0, common_1.Module)({
        imports: [
            typeorm_1.TypeOrmModule.forFeature([territory_entity_1.Territory, territory_history_entity_1.TerritoryHistory, duel_entity_1.Duel, territory_tileset_entity_1.TerritoryTileset, club_member_entity_1.ClubMember]),
            realtime_module_1.RealtimeModule,
        ],
        controllers: [territories_controller_1.TerritoriesController],
        providers: [territories_service_1.TerritoriesService],
        exports: [territories_service_1.TerritoriesService],
    })
], TerritoriesModule);
//# sourceMappingURL=territories.module.js.map