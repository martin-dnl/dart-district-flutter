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
exports.TournamentPlayer = void 0;
const typeorm_1 = require("typeorm");
const tournament_entity_1 = require("./tournament.entity");
const user_entity_1 = require("../../users/entities/user.entity");
const tournament_pool_entity_1 = require("./tournament-pool.entity");
let TournamentPlayer = class TournamentPlayer {
};
exports.TournamentPlayer = TournamentPlayer;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], TournamentPlayer.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)('uuid'),
    __metadata("design:type", String)
], TournamentPlayer.prototype, "tournament_id", void 0);
__decorate([
    (0, typeorm_1.Column)('uuid'),
    __metadata("design:type", String)
], TournamentPlayer.prototype, "user_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', nullable: true }),
    __metadata("design:type", Object)
], TournamentPlayer.prototype, "seed", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], TournamentPlayer.prototype, "pool_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'boolean', default: false }),
    __metadata("design:type", Boolean)
], TournamentPlayer.prototype, "is_qualified", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'boolean', default: false }),
    __metadata("design:type", Boolean)
], TournamentPlayer.prototype, "is_disqualified", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', nullable: true }),
    __metadata("design:type", Object)
], TournamentPlayer.prototype, "disqualification_reason", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], TournamentPlayer.prototype, "registered_at", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => tournament_entity_1.Tournament, (tournament) => tournament.players, {
        onDelete: 'CASCADE',
    }),
    (0, typeorm_1.JoinColumn)({ name: 'tournament_id' }),
    __metadata("design:type", tournament_entity_1.Tournament)
], TournamentPlayer.prototype, "tournament", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'user_id' }),
    __metadata("design:type", user_entity_1.User)
], TournamentPlayer.prototype, "user", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => tournament_pool_entity_1.TournamentPool, (pool) => pool.players, {
        onDelete: 'SET NULL',
    }),
    (0, typeorm_1.JoinColumn)({ name: 'pool_id' }),
    __metadata("design:type", Object)
], TournamentPlayer.prototype, "pool", void 0);
exports.TournamentPlayer = TournamentPlayer = __decorate([
    (0, typeorm_1.Entity)('tournament_players')
], TournamentPlayer);
//# sourceMappingURL=tournament-player.entity.js.map