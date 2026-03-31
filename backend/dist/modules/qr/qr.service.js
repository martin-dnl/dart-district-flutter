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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.QrService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const qr_code_entity_1 = require("./entities/qr-code.entity");
const crypto_1 = require("crypto");
let QrService = class QrService {
    constructor(repo) {
        this.repo = repo;
    }
    async generate(territoryId, venue) {
        const code = (0, crypto_1.randomBytes)(16).toString('hex');
        const qr = this.repo.create({
            territory_id: territoryId,
            territory: { code_iris: territoryId },
            venue_name: venue,
            code,
            is_active: true,
        });
        return this.repo.save(qr);
    }
    async findByCode(code) {
        const qr = await this.repo.findOne({
            where: { code, is_active: true },
            relations: ['territory', 'territory.owner_club'],
        });
        if (!qr)
            throw new common_1.NotFoundException('QR code not found or inactive');
        return qr;
    }
    async findByTerritory(territoryId) {
        return this.repo.find({
            where: { territory: { code_iris: territoryId }, is_active: true },
        });
    }
    async deactivate(id) {
        const qr = await this.repo.findOne({ where: { id } });
        if (!qr)
            throw new common_1.NotFoundException('QR code not found');
        qr.is_active = false;
        return this.repo.save(qr);
    }
};
exports.QrService = QrService;
exports.QrService = QrService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(qr_code_entity_1.QrCode)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], QrService);
//# sourceMappingURL=qr.service.js.map