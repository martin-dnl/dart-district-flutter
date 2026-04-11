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
exports.DartSenseController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const platform_express_1 = require("@nestjs/platform-express");
const multer_1 = require("multer");
const jwt_auth_guard_1 = require("../auth/guards/jwt-auth.guard");
const dart_sense_service_1 = require("./dart-sense.service");
let DartSenseController = class DartSenseController {
    constructor(dartSenseService) {
        this.dartSenseService = dartSenseService;
    }
    detect(file) {
        return this.dartSenseService.detect(file);
    }
    detectBatch(files, minOccurrences, maxFrames) {
        const parsedMin = minOccurrences ? Number.parseInt(minOccurrences, 10) : 2;
        const parsedMax = maxFrames ? Number.parseInt(maxFrames, 10) : 24;
        return this.dartSenseService.detectBatch(files ?? [], parsedMin, parsedMax);
    }
    feedback(file, zone, multiplier, source, note) {
        const parsedZone = Number.parseInt(zone ?? '', 10);
        const parsedMultiplier = Number.parseInt(multiplier ?? '', 10);
        return this.dartSenseService.feedback(file, parsedZone, parsedMultiplier, source, note);
    }
};
exports.DartSenseController = DartSenseController;
__decorate([
    (0, common_1.Post)('detect'),
    (0, swagger_1.ApiConsumes)('multipart/form-data'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('image', {
        storage: (0, multer_1.memoryStorage)(),
        limits: {
            fileSize: 10 * 1024 * 1024,
        },
    })),
    __param(0, (0, common_1.UploadedFile)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], DartSenseController.prototype, "detect", null);
__decorate([
    (0, common_1.Post)('detect/batch'),
    (0, swagger_1.ApiConsumes)('multipart/form-data'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FilesInterceptor)('images', 24, {
        storage: (0, multer_1.memoryStorage)(),
        limits: {
            fileSize: 10 * 1024 * 1024,
        },
    })),
    __param(0, (0, common_1.UploadedFiles)()),
    __param(1, (0, common_1.Query)('min_occurrences')),
    __param(2, (0, common_1.Query)('max_frames')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Array, String, String]),
    __metadata("design:returntype", void 0)
], DartSenseController.prototype, "detectBatch", null);
__decorate([
    (0, common_1.Post)('feedback'),
    (0, swagger_1.ApiConsumes)('multipart/form-data'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('image', {
        storage: (0, multer_1.memoryStorage)(),
        limits: {
            fileSize: 10 * 1024 * 1024,
        },
    })),
    __param(0, (0, common_1.UploadedFile)()),
    __param(1, (0, common_1.Body)('zone')),
    __param(2, (0, common_1.Body)('multiplier')),
    __param(3, (0, common_1.Body)('source')),
    __param(4, (0, common_1.Body)('note')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String, String, String, String]),
    __metadata("design:returntype", void 0)
], DartSenseController.prototype, "feedback", null);
exports.DartSenseController = DartSenseController = __decorate([
    (0, swagger_1.ApiTags)('dart-sense'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('dart-sense'),
    __metadata("design:paramtypes", [dart_sense_service_1.DartSenseService])
], DartSenseController);
//# sourceMappingURL=dart-sense.controller.js.map