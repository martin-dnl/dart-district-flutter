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
exports.Match = void 0;
const typeorm_1 = require("typeorm");
const match_player_entity_1 = require("./match-player.entity");
const set_entity_1 = require("./set.entity");
const territory_entity_1 = require("../../territories/entities/territory.entity");
const user_entity_1 = require("../../users/entities/user.entity");
let Match = class Match {
};
exports.Match = Match;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Match.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'enum', enum: ['301', '501', '701', 'cricket', 'chasseur'] }),
    __metadata("design:type", String)
], Match.prototype, "mode", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'enum', enum: ['double_out', 'single_out', 'master_out'], default: 'double_out' }),
    __metadata("design:type", String)
], Match.prototype, "finish", void 0);
__decorate([
    (0, typeorm_1.Column)({
        type: 'enum',
        enum: ['pending', 'in_progress', 'paused', 'completed', 'cancelled', 'awaiting_validation'],
        default: 'pending',
    }),
    __metadata("design:type", String)
], Match.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 1 }),
    __metadata("design:type", Number)
], Match.prototype, "total_sets", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 3 }),
    __metadata("design:type", Number)
], Match.prototype, "legs_per_set", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Match.prototype, "inviter_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Match.prototype, "invitee_id", void 0);
__decorate([
    (0, typeorm_1.Column)({
        type: 'enum',
        enum: ['pending', 'accepted', 'refused'],
        nullable: true,
    }),
    __metadata("design:type", Object)
], Match.prototype, "invitation_status", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Match.prototype, "invitation_created_at", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 9, nullable: true }),
    __metadata("design:type", Object)
], Match.prototype, "territory_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'boolean', default: false }),
    __metadata("design:type", Boolean)
], Match.prototype, "is_territorial", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Match.prototype, "tournament_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'boolean', default: false }),
    __metadata("design:type", Boolean)
], Match.prototype, "is_offline", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'boolean', default: false }),
    __metadata("design:type", Boolean)
], Match.prototype, "is_ranked", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Match.prototype, "surrendered_by", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'boolean', default: false }),
    __metadata("design:type", Boolean)
], Match.prototype, "validated_by_home", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'boolean', default: false }),
    __metadata("design:type", Boolean)
], Match.prototype, "validated_by_away", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Match.prototype, "started_at", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Match.prototype, "ended_at", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], Match.prototype, "created_at", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => match_player_entity_1.MatchPlayer, (mp) => mp.match),
    __metadata("design:type", Array)
], Match.prototype, "players", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => set_entity_1.Set, (s) => s.match),
    __metadata("design:type", Array)
], Match.prototype, "sets", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => territory_entity_1.Territory, { onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'territory_id' }),
    __metadata("design:type", territory_entity_1.Territory)
], Match.prototype, "territory", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'surrendered_by' }),
    __metadata("design:type", user_entity_1.User)
], Match.prototype, "surrendered_by_user", void 0);
exports.Match = Match = __decorate([
    (0, typeorm_1.Entity)('matches')
], Match);
//# sourceMappingURL=match.entity.js.map