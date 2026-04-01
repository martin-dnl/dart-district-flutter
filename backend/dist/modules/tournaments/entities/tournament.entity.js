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
exports.Tournament = void 0;
const typeorm_1 = require("typeorm");
const territory_entity_1 = require("../../territories/entities/territory.entity");
const user_entity_1 = require("../../users/entities/user.entity");
const tournament_player_entity_1 = require("./tournament-player.entity");
const tournament_pool_entity_1 = require("./tournament-pool.entity");
const tournament_bracket_match_entity_1 = require("./tournament-bracket-match.entity");
let Tournament = class Tournament {
};
exports.Tournament = Tournament;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Tournament.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 150 }),
    __metadata("design:type", String)
], Tournament.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', nullable: true }),
    __metadata("design:type", Object)
], Tournament.prototype, "description", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 9, nullable: true }),
    __metadata("design:type", Object)
], Tournament.prototype, "territory_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'boolean', default: false }),
    __metadata("design:type", Boolean)
], Tournament.prototype, "is_territorial", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'enum', enum: ['301', '501', '701', 'cricket', 'chasseur'], default: '501' }),
    __metadata("design:type", String)
], Tournament.prototype, "mode", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'enum', enum: ['double_out', 'single_out', 'master_out'], default: 'double_out' }),
    __metadata("design:type", String)
], Tournament.prototype, "finish", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 200, nullable: true }),
    __metadata("design:type", Object)
], Tournament.prototype, "venue_name", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'text', nullable: true }),
    __metadata("design:type", Object)
], Tournament.prototype, "venue_address", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 100, nullable: true }),
    __metadata("design:type", Object)
], Tournament.prototype, "city", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'numeric', precision: 8, scale: 2, default: 0 }),
    __metadata("design:type", Number)
], Tournament.prototype, "entry_fee", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 16 }),
    __metadata("design:type", Number)
], Tournament.prototype, "max_players", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 0 }),
    __metadata("design:type", Number)
], Tournament.prototype, "enrolled_players", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 20, default: 'single_elimination' }),
    __metadata("design:type", String)
], Tournament.prototype, "format", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', nullable: true }),
    __metadata("design:type", Object)
], Tournament.prototype, "pool_count", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', nullable: true }),
    __metadata("design:type", Object)
], Tournament.prototype, "players_per_pool", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 2 }),
    __metadata("design:type", Number)
], Tournament.prototype, "qualified_per_pool", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 3 }),
    __metadata("design:type", Number)
], Tournament.prototype, "legs_per_set_pool", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 1 }),
    __metadata("design:type", Number)
], Tournament.prototype, "sets_to_win_pool", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 5 }),
    __metadata("design:type", Number)
], Tournament.prototype, "legs_per_set_bracket", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 1 }),
    __metadata("design:type", Number)
], Tournament.prototype, "sets_to_win_bracket", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 20, default: 'registration' }),
    __metadata("design:type", String)
], Tournament.prototype, "current_phase", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 30, default: 'open' }),
    __metadata("design:type", String)
], Tournament.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], Tournament.prototype, "scheduled_at", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Tournament.prototype, "ended_at", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Tournament.prototype, "created_by", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], Tournament.prototype, "created_at", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => territory_entity_1.Territory, { onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'territory_id' }),
    __metadata("design:type", territory_entity_1.Territory)
], Tournament.prototype, "territory", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'created_by' }),
    __metadata("design:type", user_entity_1.User)
], Tournament.prototype, "creator", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => tournament_player_entity_1.TournamentPlayer, (player) => player.tournament),
    __metadata("design:type", Array)
], Tournament.prototype, "players", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => tournament_pool_entity_1.TournamentPool, (pool) => pool.tournament),
    __metadata("design:type", Array)
], Tournament.prototype, "pools", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => tournament_bracket_match_entity_1.TournamentBracketMatch, (match) => match.tournament),
    __metadata("design:type", Array)
], Tournament.prototype, "bracket_matches", void 0);
exports.Tournament = Tournament = __decorate([
    (0, typeorm_1.Entity)('tournaments')
], Tournament);
//# sourceMappingURL=tournament.entity.js.map