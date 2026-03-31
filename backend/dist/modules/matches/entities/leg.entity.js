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
exports.Leg = void 0;
const typeorm_1 = require("typeorm");
const set_entity_1 = require("./set.entity");
const user_entity_1 = require("../../users/entities/user.entity");
const throw_entity_1 = require("./throw.entity");
let Leg = class Leg {
};
exports.Leg = Leg;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], Leg.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid' }),
    __metadata("design:type", String)
], Leg.prototype, "set_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int' }),
    __metadata("design:type", Number)
], Leg.prototype, "leg_number", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'uuid', nullable: true }),
    __metadata("design:type", Object)
], Leg.prototype, "winner_id", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'int', default: 501 }),
    __metadata("design:type", Number)
], Leg.prototype, "starting_score", void 0);
__decorate([
    (0, typeorm_1.CreateDateColumn)({ type: 'timestamptz' }),
    __metadata("design:type", Date)
], Leg.prototype, "created_at", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => set_entity_1.Set, (s) => s.legs, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'set_id' }),
    __metadata("design:type", set_entity_1.Set)
], Leg.prototype, "set", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => user_entity_1.User, { onDelete: 'SET NULL' }),
    (0, typeorm_1.JoinColumn)({ name: 'winner_id' }),
    __metadata("design:type", user_entity_1.User)
], Leg.prototype, "winner", void 0);
__decorate([
    (0, typeorm_1.OneToMany)(() => throw_entity_1.Throw, (t) => t.leg),
    __metadata("design:type", Array)
], Leg.prototype, "throws", void 0);
exports.Leg = Leg = __decorate([
    (0, typeorm_1.Entity)('legs')
], Leg);
//# sourceMappingURL=leg.entity.js.map