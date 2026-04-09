"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.I18nModule = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const i18n_controller_1 = require("./i18n.controller");
const i18n_service_1 = require("./i18n.service");
const language_entity_1 = require("./entities/language.entity");
const translation_entity_1 = require("./entities/translation.entity");
let I18nModule = class I18nModule {
};
exports.I18nModule = I18nModule;
exports.I18nModule = I18nModule = __decorate([
    (0, common_1.Module)({
        imports: [typeorm_1.TypeOrmModule.forFeature([language_entity_1.Language, translation_entity_1.Translation])],
        controllers: [i18n_controller_1.I18nController],
        providers: [i18n_service_1.I18nService],
        exports: [i18n_service_1.I18nService],
    })
], I18nModule);
//# sourceMappingURL=i18n.module.js.map