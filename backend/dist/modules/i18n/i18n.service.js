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
exports.I18nService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const language_entity_1 = require("./entities/language.entity");
const translation_entity_1 = require("./entities/translation.entity");
let I18nService = class I18nService {
    constructor(languageRepo, translationRepo) {
        this.languageRepo = languageRepo;
        this.translationRepo = translationRepo;
    }
    async getLanguages(availableOnly = false) {
        const qb = this.languageRepo
            .createQueryBuilder('language')
            .orderBy('language.country_name', 'ASC');
        if (availableOnly) {
            qb.where('language.is_available = :available', { available: true });
        }
        return qb.getMany();
    }
    async getTranslations(languageCode) {
        const code = languageCode.trim();
        const rows = await this.translationRepo.find({
            where: { language_code: code },
            order: { key: 'ASC' },
        });
        return rows.reduce((acc, row) => {
            acc[row.key] = row.value;
            return acc;
        }, {});
    }
};
exports.I18nService = I18nService;
exports.I18nService = I18nService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(language_entity_1.Language)),
    __param(1, (0, typeorm_1.InjectRepository)(translation_entity_1.Translation)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository])
], I18nService);
//# sourceMappingURL=i18n.service.js.map