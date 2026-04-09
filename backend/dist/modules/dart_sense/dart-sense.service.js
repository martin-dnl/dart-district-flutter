"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var DartSenseService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.DartSenseService = void 0;
const common_1 = require("@nestjs/common");
let DartSenseService = DartSenseService_1 = class DartSenseService {
    constructor() {
        this.logger = new common_1.Logger(DartSenseService_1.name);
    }
    async detect(image) {
        if (!image) {
            throw new common_1.BadRequestException('image is required');
        }
        const baseUrl = process.env.DART_SENSE_BASE_URL?.trim() ||
            process.env.DART_SENSE_URL?.trim() ||
            'http://localhost:8001';
        const form = new FormData();
        form.append('image', new Blob([new Uint8Array(image.buffer)], {
            type: image.mimetype || 'image/jpeg',
        }), image.originalname || 'capture.jpg');
        let response;
        try {
            response = await fetch(`${baseUrl.replace(/\/+$/, '')}/detect`, {
                method: 'POST',
                body: form,
            });
        }
        catch (error) {
            this.logger.error(`Dart Sense connection failed: ${String(error)}`);
            throw new common_1.BadGatewayException('Dart Sense service unavailable');
        }
        let payload;
        try {
            payload = await response.json();
        }
        catch (_) {
            throw new common_1.BadGatewayException('Invalid response from Dart Sense service');
        }
        if (!response.ok) {
            throw new common_1.BadGatewayException('Dart Sense detection failed');
        }
        const body = payload && typeof payload === 'object'
            ? payload
            : {};
        const data = body['data'] && typeof body['data'] === 'object'
            ? body['data']
            : body;
        const darts = Array.isArray(data['darts']) ? data['darts'] : [];
        return { darts };
    }
};
exports.DartSenseService = DartSenseService;
exports.DartSenseService = DartSenseService = DartSenseService_1 = __decorate([
    (0, common_1.Injectable)()
], DartSenseService);
//# sourceMappingURL=dart-sense.service.js.map