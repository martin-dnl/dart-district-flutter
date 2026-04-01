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
Object.defineProperty(exports, "__esModule", { value: true });
exports.TournamentPool = void 0;
const typeorm_1 = require("typeorm");
const tournament_entity_1 = require("./tournament.entity");
const tournament_player_entity_1 = require("./tournament-player.entity");
const tournament_pool_standing_entity_1 = require("./tournament-pool-standing.entity");
let TournamentPool = class TournamentPool {
};
exports.TournamentPool = TournamentPool;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], TournamentPool.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)('uuid'),
    __metadata("design:type", String)
], TournamentPool.prototype, "tournament_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 10 }),
    __metadata("design:type", String)
], TournamentPool.prototype, "pool_name", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], TournamentPool.prototype, "created_at", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => tournament_entity_1.Tournament, (tournament) => tournament.pools, {
        onDelete: 'CASCADE',
    }),
    (0, typeorm_1.JoinColumn)({ name: 'tournament_id' }),
    __metadata("design:type", tournament_entity_1.Tournament)
], TournamentPool.prototype, "tournament", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => tournament_player_entity_1.TournamentPlayer, (player) => player.pool),
    __metadata("design:type", Array)
], TournamentPool.prototype, "players", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => tournament_pool_standing_entity_1.TournamentPoolStanding, (standing) => standing.pool),
    __metadata("design:type", Array)
], TournamentPool.prototype, "standings", void 0);
exports.TournamentPool = TournamentPool = __decorate([
    (0, typeorm_1.Entity)('tournament_pools')
], TournamentPool);
//# sourceMappingURL=tournament-pool.entity.js.map