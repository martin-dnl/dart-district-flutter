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
    get baseUrl() {
        return (process.env.DART_SENSE_BASE_URL?.trim() ||
            process.env.DART_SENSE_URL?.trim() ||
            'http://dartdistrict-dart-sense:8000');
    }
    appendFileToForm(form, fieldName, image) {
        form.append(fieldName, new Blob([new Uint8Array(image.buffer)], {
            type: image.mimetype || 'image/jpeg',
        }), image.originalname || 'capture.jpg');
    }
    async detect(image) {
        if (!image) {
            throw new common_1.BadRequestException('image is required');
        }
        const form = new FormData();
        this.appendFileToForm(form, 'image', image);
        let response;
        try {
            response = await fetch(`${this.baseUrl.replace(/\/+$/, '')}/detect`, {
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
    async detectBatch(images, minOccurrences = 2, maxFrames = 24) {
        if (!images.length) {
            throw new common_1.BadRequestException('images are required');
        }
        const form = new FormData();
        for (const image of images.slice(0, Math.max(1, maxFrames))) {
            this.appendFileToForm(form, 'images', image);
        }
        const min = Number.isFinite(minOccurrences)
            ? Math.min(10, Math.max(1, minOccurrences))
            : 2;
        const max = Number.isFinite(maxFrames)
            ? Math.min(60, Math.max(1, maxFrames))
            : 24;
        let response;
        try {
            response = await fetch(`${this.baseUrl.replace(/\/+$/, '')}/detect/batch?min_occurrences=${min}&max_frames=${max}`, {
                method: 'POST',
                body: form,
            });
        }
        catch (error) {
            this.logger.error(`Dart Sense batch connection failed: ${String(error)}`);
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
            throw new common_1.BadGatewayException('Dart Sense batch detection failed');
        }
        const body = payload && typeof payload === 'object'
            ? payload
            : {};
        const data = body['data'] && typeof body['data'] === 'object'
            ? body['data']
            : body;
        return {
            darts: Array.isArray(data['darts']) ? data['darts'] : [],
            frames: Array.isArray(data['frames']) ? data['frames'] : [],
            framesProcessed: typeof data['frames_processed'] === 'number' ? data['frames_processed'] : 0,
            minOccurrences: typeof data['min_occurrences'] === 'number' ? data['min_occurrences'] : min,
        };
    }
    async feedback(image, zone, multiplier, source, note) {
        if (!image) {
            throw new common_1.BadRequestException('image is required');
        }
        if (!Number.isInteger(zone) || zone < 1 || zone > 25) {
            throw new common_1.BadRequestException('zone must be between 1 and 25');
        }
        if (!Number.isInteger(multiplier) || multiplier < 1 || multiplier > 3) {
            throw new common_1.BadRequestException('multiplier must be between 1 and 3');
        }
        if (zone === 25 && multiplier > 2) {
            throw new common_1.BadRequestException('bull multiplier must be 1 or 2');
        }
        const form = new FormData();
        this.appendFileToForm(form, 'image', image);
        form.append('zone', `${zone}`);
        form.append('multiplier', `${multiplier}`);
        form.append('source', (source ?? 'mobile_app').trim() || 'mobile_app');
        if (note && note.trim().length > 0) {
            form.append('note', note.trim().slice(0, 240));
        }
        let response;
        try {
            response = await fetch(`${this.baseUrl.replace(/\/+$/, '')}/feedback`, {
                method: 'POST',
                body: form,
            });
        }
        catch (error) {
            this.logger.error(`Dart Sense feedback connection failed: ${String(error)}`);
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
            throw new common_1.BadGatewayException('Dart Sense feedback failed');
        }
        const body = payload && typeof payload === 'object'
            ? payload
            : {};
        const data = body['data'] && typeof body['data'] === 'object'
            ? body['data']
            : body;
        return {
            sample: data['sample'] && typeof data['sample'] === 'object'
                ? data['sample']
                : null,
            message: typeof data['message'] === 'string'
                ? data['message']
                : 'Feedback saved',
        };
    }
};
exports.DartSenseService = DartSenseService;
exports.DartSenseService = DartSenseService = DartSenseService_1 = __decorate([
    (0, common_1.Injectable)()
], DartSenseService);
//# sourceMappingURL=dart-sense.service.js.map