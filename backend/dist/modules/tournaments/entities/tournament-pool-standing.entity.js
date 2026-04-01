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
exports.TournamentPoolStanding = void 0;
const typeorm_1 = require("typeorm");
const tournament_pool_entity_1 = require("./tournament-pool.entity");
const user_entity_1 = require("../../users/entities/user.entity");
let TournamentPoolStanding = class TournamentPoolStanding {
};
exports.TournamentPoolStanding = TournamentPoolStanding;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], TournamentPoolStanding.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)('uuid'),
    __metadata("design:type", String)
], TournamentPoolStanding.prototype, "pool_id", void 0);
__decorate([
    (0, typeorm_1.Column)('uuid'),
    __metadata("design:type", String)
], TournamentPoolStanding.prototype, "user_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 0 }),
    __metadata("design:type", Number)
], TournamentPoolStanding.prototype, "matches_played", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 0 }),
    __metadata("design:type", Number)
], TournamentPoolStanding.prototype, "matches_won", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 0 }),
    __metadata("design:type", Number)
], TournamentPoolStanding.prototype, "legs_won", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 0 }),
    __metadata("design:type", Number)
], TournamentPoolStanding.prototype, "legs_lost", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 0 }),
    __metadata("design:type", Number)
], TournamentPoolStanding.prototype, "points", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', nullable: true }),
    __metadata("design:type", Object)
], TournamentPoolStanding.prototype, "rank", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => tournament_pool_entity_1.TournamentPool, (pool) => pool.standings, {
        onDelete: 'CASCADE',
    }),
    (0, typeorm_1.JoinColumn)({ name: 'pool_id' }),
    __metadata("design:type", tournament_pool_entity_1.TournamentPool)
], TournamentPoolStanding.prototype, "pool", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'user_id' }),
    __metadata("design:type", user_entity_1.User)
], TournamentPoolStanding.prototype, "user", void 0);
exports.TournamentPoolStanding = TournamentPoolStanding = __decorate([
    (0, typeorm_1.Entity)('tournament_pool_standings')
], TournamentPoolStanding);
//# sourceMappingURL=tournament-pool-standing.entity.js.map