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
exports.TerritoryHistory = void 0;
const typeorm_1 = require("typeorm");
const territory_entity_1 = require("./territory.entity");
const club_entity_1 = require("../../clubs/entities/club.entity");
let TerritoryHistory = class TerritoryHistory {
};
exports.TerritoryHistory = TerritoryHistory;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], TerritoryHistory.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 9 }),
    __metadata("design:type", String)
], TerritoryHistory.prototype, "territory_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], TerritoryHistory.prototype, "from_club_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], TerritoryHistory.prototype, "to_club_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], TerritoryHistory.prototype, "match_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 50 }),
    __metadata("design:type", String)
], TerritoryHistory.prototype, "event", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], TerritoryHistory.prototype, "created_at", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => territory_entity_1.Territory, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'territory_id' }),
    __metadata("design:type", territory_entity_1.Territory)
], TerritoryHistory.prototype, "territory", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => club_entity_1.Club, { onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'from_club_id' }),
    __metadata("design:type", club_entity_1.Club)
], TerritoryHistory.prototype, "from_club", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => club_entity_1.Club, { onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'to_club_id' }),
    __metadata("design:type", club_entity_1.Club)
], TerritoryHistory.prototype, "to_club", void 0);
exports.TerritoryHistory = TerritoryHistory = __decorate([
    (0, typeorm_1.Entity)('territory_history')
], TerritoryHistory);
//# sourceMappingURL=territory-history.entity.js.map