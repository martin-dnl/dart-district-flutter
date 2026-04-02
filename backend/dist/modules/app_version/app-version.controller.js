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
exports.AppVersionController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const app_version_service_1 = require("./app-version.service");
let AppVersionController = class AppVersionController {
    constructor(appVersionService) {
        this.appVersionService = appVersionService;
    }
    getVersionPolicy(platform, appVersion, appBuild) {
        return this.appVersionService.getPolicyForClient(platform, appVersion, appBuild);
    }
};
exports.AppVersionController = AppVersionController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('platform')),
    __param(1, (0, common_1.Query)('app_version')),
    __param(2, (0, common_1.Query)('app_build')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String]),
    __metadata("design:returntype", void 0)
], AppVersionController.prototype, "getVersionPolicy", null);
exports.AppVersionController = AppVersionController = __decorate([
    (0, swagger_1.ApiTags)('app-version'),
    (0, common_1.Controller)('app/version'),
    __metadata("design:paramtypes", [app_version_service_1.AppVersionService])
], AppVersionController);
//# sourceMappingURL=app-version.controller.js.map