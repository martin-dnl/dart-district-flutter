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
exports.ClubTerritoryPoints = void 0;
const typeorm_1 = require("typeorm");
const club_entity_1 = require("./club.entity");
let ClubTerritoryPoints = class ClubTerritoryPoints {
};
exports.ClubTerritoryPoints = ClubTerritoryPoints;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], ClubTerritoryPoints.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid' }),
    __metadata("design:type", String)
], ClubTerritoryPoints.prototype, "club_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 9 }),
    __metadata("design:type", String)
], ClubTerritoryPoints.prototype, "code_iris", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 0 }),
    __metadata("design:type", Number)
], ClubTerritoryPoints.prototype, "points", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], ClubTerritoryPoints.prototype, "created_at", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], ClubTerritoryPoints.prototype, "updated_at", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => club_entity_1.Club, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'club_id' }),
    __metadata("design:type", club_entity_1.Club)
], ClubTerritoryPoints.prototype, "club", void 0);
exports.ClubTerritoryPoints = ClubTerritoryPoints = __decorate([
    (0, typeorm_1.Entity)('club_territory_points'),
    (0, typeorm_1.Unique)(['club_id', 'code_iris'])
], ClubTerritoryPoints);
//# sourceMappingURL=club-territory-points.entity.js.map