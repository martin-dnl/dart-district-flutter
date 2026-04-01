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
exports.TournamentBracketMatch = void 0;
const typeorm_1 = require("typeorm");
const tournament_entity_1 = require("./tournament.entity");
const user_entity_1 = require("../../users/entities/user.entity");
let TournamentBracketMatch = class TournamentBracketMatch {
};
exports.TournamentBracketMatch = TournamentBracketMatch;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], TournamentBracketMatch.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)('uuid'),
    __metadata("design:type", String)
], TournamentBracketMatch.prototype, "tournament_id", void 0);
__decorate([
    (0, typeorm_1.Column)('int'),
    __metadata("design:type", Number)
], TournamentBracketMatch.prototype, "round_number", void 0);
__decorate([
    (0, typeorm_1.Column)('int'),
    __metadata("design:type", Number)
], TournamentBracketMatch.prototype, "position", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], TournamentBracketMatch.prototype, "player1_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], TournamentBracketMatch.prototype, "player2_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], TournamentBracketMatch.prototype, "winner_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], TournamentBracketMatch.prototype, "match_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 20, default: 'pending' }),
    __metadata("design:type", String)
], TournamentBracketMatch.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], TournamentBracketMatch.prototype, "scheduled_at", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => tournament_entity_1.Tournament, (tournament) => tournament.bracket_matches, {
        onDelete: 'CASCADE',
    }),
    (0, typeorm_1.JoinColumn)({ name: 'tournament_id' }),
    __metadata("design:type", tournament_entity_1.Tournament)
], TournamentBracketMatch.prototype, "tournament", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'player1_id' }),
    __metadata("design:type", Object)
], TournamentBracketMatch.prototype, "player1", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'player2_id' }),
    __metadata("design:type", Object)
], TournamentBracketMatch.prototype, "player2", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'winner_id' }),
    __metadata("design:type", Object)
], TournamentBracketMatch.prototype, "winner", void 0);
exports.TournamentBracketMatch = TournamentBracketMatch = __decorate([
    (0, typeorm_1.Entity)('tournament_bracket_matches')
], TournamentBracketMatch);
//# sourceMappingURL=tournament-bracket-match.entity.js.map