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
exports.Duel = void 0;
const typeorm_1 = require("typeorm");
const territory_entity_1 = require("../../territories/entities/territory.entity");
const user_entity_1 = require("../../users/entities/user.entity");
const club_entity_1 = require("../../clubs/entities/club.entity");
const match_entity_1 = require("../../matches/entities/match.entity");
let Duel = class Duel {
};
exports.Duel = Duel;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Duel.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 9 }),
    __metadata("design:type", String)
], Duel.prototype, "territory_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid' }),
    __metadata("design:type", String)
], Duel.prototype, "challenger_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Duel.prototype, "defender_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid' }),
    __metadata("design:type", String)
], Duel.prototype, "challenger_club", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Duel.prototype, "defender_club", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Duel.prototype, "match_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Duel.prototype, "qr_code_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'enum', enum: ['pending', 'accepted', 'declined', 'expired', 'completed'], default: 'pending' }),
    __metadata("design:type", String)
], Duel.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], Duel.prototype, "expires_at", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], Duel.prototype, "created_at", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => territory_entity_1.Territory, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'territory_id' }),
    __metadata("design:type", territory_entity_1.Territory)
], Duel.prototype, "territory", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User),
    (0, typeorm_1.JoinColumn)({ name: 'challenger_id' }),
    __metadata("design:type", user_entity_1.User)
], Duel.prototype, "challenger", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { nullable: true }),
    (0, typeorm_1.JoinColumn)({ name: 'defender_id' }),
    __metadata("design:type", user_entity_1.User)
], Duel.prototype, "defender", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => club_entity_1.Club),
    (0, typeorm_1.JoinColumn)({ name: 'challenger_club', referencedColumnName: 'id' }),
    __metadata("design:type", club_entity_1.Club)
], Duel.prototype, "challengerClub", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => club_entity_1.Club, { nullable: true }),
    (0, typeorm_1.JoinColumn)({ name: 'defender_club', referencedColumnName: 'id' }),
    __metadata("design:type", club_entity_1.Club)
], Duel.prototype, "defenderClub", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => match_entity_1.Match, { nullable: true }),
    (0, typeorm_1.JoinColumn)({ name: 'match_id' }),
    __metadata("design:type", match_entity_1.Match)
], Duel.prototype, "match", void 0);
exports.Duel = Duel = __decorate([
    (0, typeorm_1.Entity)('duels')
], Duel);
//# sourceMappingURL=duel.entity.js.map