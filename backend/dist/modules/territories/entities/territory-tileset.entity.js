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
exports.TerritoryTileset = void 0;
const typeorm_1 = require("typeorm");
let TerritoryTileset = class TerritoryTileset {
};
exports.TerritoryTileset = TerritoryTileset;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], TerritoryTileset.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 100, unique: true }),
    __metadata("design:type", String)
], TerritoryTileset.prototype, "key", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 50 }),
    __metadata("design:type", String)
], TerritoryTileset.prototype, "format", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 255 }),
    __metadata("design:type", String)
], TerritoryTileset.prototype, "source_url", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 120 }),
    __metadata("design:type", String)
], TerritoryTileset.prototype, "attribution", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 0 }),
    __metadata("design:type", Number)
], TerritoryTileset.prototype, "minzoom", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 14 }),
    __metadata("design:type", Number)
], TerritoryTileset.prototype, "maxzoom", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'numeric', precision: 10, scale: 6, nullable: true }),
    __metadata("design:type", Object)
], TerritoryTileset.prototype, "bounds_west", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'numeric', precision: 10, scale: 6, nullable: true }),
    __metadata("design:type", Object)
], TerritoryTileset.prototype, "bounds_south", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'numeric', precision: 10, scale: 6, nullable: true }),
    __metadata("design:type", Object)
], TerritoryTileset.prototype, "bounds_east", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'numeric', precision: 10, scale: 6, nullable: true }),
    __metadata("design:type", Object)
], TerritoryTileset.prototype, "bounds_north", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'numeric', precision: 10, scale: 6, nullable: true }),
    __metadata("design:type", Object)
], TerritoryTileset.prototype, "center_lng", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'numeric', precision: 10, scale: 6, nullable: true }),
    __metadata("design:type", Object)
], TerritoryTileset.prototype, "center_lat", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', nullable: true }),
    __metadata("design:type", Object)
], TerritoryTileset.prototype, "center_zoom", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 100, nullable: true }),
    __metadata("design:type", Object)
], TerritoryTileset.prototype, "layer_name", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'boolean', default: true }),
    __metadata("design:type", Boolean)
], TerritoryTileset.prototype, "is_active", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], TerritoryTileset.prototype, "created_at", void 0);
__decorate([
    (0, typeorm_1.UpdateDateColumn)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], TerritoryTileset.prototype, "updated_at", void 0);
exports.TerritoryTileset = TerritoryTileset = __decorate([
    (0, typeorm_1.Entity)('territory_tilesets')
], TerritoryTileset);
//# sourceMappingURL=territory-tileset.entity.js.map