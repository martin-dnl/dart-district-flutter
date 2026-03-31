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
exports.Territory = void 0;
const typeorm_1 = require("typeorm");
const club_entity_1 = require("../../clubs/entities/club.entity");
let Territory = class Territory {
};
exports.Territory = Territory;
__decorate([
    (0, typeorm_1.PrimaryColumn)({ type: 'varchar', length: 9 }),
    __metadata("design:type", String)
], Territory.prototype, "code_iris", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 255 }),
    __metadata("design:type", String)
], Territory.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 5, nullable: true }),
    __metadata("design:type", Object)
], Territory.prototype, "insee_com", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 150, nullable: true }),
    __metadata("design:type", Object)
], Territory.prototype, "nom_com", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 100, nullable: true }),
    __metadata("design:type", Object)
], Territory.prototype, "nom_iris", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 30, nullable: true }),
    __metadata("design:type", Object)
], Territory.prototype, "iris_type", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 3, nullable: true }),
    __metadata("design:type", Object)
], Territory.prototype, "dep_code", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 2, nullable: true }),
    __metadata("design:type", Object)
], Territory.prototype, "dep_name", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 3, nullable: true }),
    __metadata("design:type", Object)
], Territory.prototype, "region_code", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 120, nullable: true }),
    __metadata("design:type", Object)
], Territory.prototype, "region_name", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', nullable: true }),
    __metadata("design:type", Object)
], Territory.prototype, "population", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'numeric', precision: 10, scale: 7 }),
    __metadata("design:type", Number)
], Territory.prototype, "centroid_lat", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'numeric', precision: 10, scale: 7 }),
    __metadata("design:type", Number)
], Territory.prototype, "centroid_lng", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'numeric', precision: 12, scale: 2, nullable: true }),
    __metadata("design:type", Object)
], Territory.prototype, "area_m2", void 0);
__decorate([
    (0, typeorm_1.Column)({
        type: 'enum',
        enum: ['available', 'locked', 'alert', 'conquered', 'conflict'],
        default: 'available',
    }),
    __metadata("design:type", String)
], Territory.prototype, "status", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Territory.prototype, "owner_club_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'timestamptz', nullable: true }),
    __metadata("design:type", Object)
], Territory.prototype, "conquered_at", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], Territory.prototype, "created_at", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], Territory.prototype, "updated_at", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => club_entity_1.Club, { onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'owner_club_id' }),
    __metadata("design:type", club_entity_1.Club)
], Territory.prototype, "owner_club", void 0);
exports.Territory = Territory = __decorate([
    (0, typeorm_1.Entity)('territories')
], Territory);
//# sourceMappingURL=territory.entity.js.map