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
exports.AppVersionService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const app_version_policy_entity_1 = require("./entities/app-version-policy.entity");
let AppVersionService = class AppVersionService {
    constructor(repo) {
        this.repo = repo;
    }
    async getPolicyForClient(platformRaw, appVersion) {
        const platform = this.normalizePlatform(platformRaw);
        const policy = await this.repo.findOne({
            where: { platform, is_active: true },
            order: { updated_at: 'DESC' },
        });
        if (!policy) {
            throw new common_1.NotFoundException(`No active app version policy for ${platform}`);
        }
        const status = this.resolveStatus(appVersion, policy);
        return {
            platform,
            min_version: policy.min_version,
            recommended_version: policy.recommended_version,
            store_url_android: policy.store_url_android,
            store_url_ios: policy.store_url_ios,
            message_force_update: policy.message_force_update,
            message_soft_update: policy.message_soft_update,
            status,
            ttl_seconds: 3600,
            server_time: new Date().toISOString(),
        };
    }
    normalizePlatform(value) {
        const platform = (value ?? '').trim().toLowerCase();
        if (platform !== 'android' && platform !== 'ios') {
            throw new common_1.BadRequestException('platform must be android or ios');
        }
        return platform;
    }
    resolveStatus(installedVersion, policy) {
        if (!installedVersion || !installedVersion.trim()) {
            return 'up_to_date';
        }
        const installed = this.normalizeVersion(installedVersion);
        const minVersion = this.normalizeVersion(policy.min_version);
        const recommendedVersion = this.normalizeVersion(policy.recommended_version);
        if (this.compareVersions(installed, minVersion) < 0) {
            return 'force_update';
        }
        if (this.compareVersions(installed, recommendedVersion) < 0) {
            return 'soft_update';
        }
        return 'up_to_date';
    }
    normalizeVersion(raw) {
        const clean = raw.trim().replace(/^v/i, '');
        const valid = /^\d+(\.\d+){0,3}$/.test(clean);
        if (!valid) {
            throw new common_1.BadRequestException(`Invalid version format: ${raw}`);
        }
        return clean;
    }
    compareVersions(a, b) {
        const aParts = a.split('.').map((part) => Number.parseInt(part, 10));
        const bParts = b.split('.').map((part) => Number.parseInt(part, 10));
        const maxLen = Math.max(aParts.length, bParts.length);
        for (let i = 0; i < maxLen; i += 1) {
            const left = aParts[i] ?? 0;
            const right = bParts[i] ?? 0;
            if (left < right)
                return -1;
            if (left > right)
                return 1;
        }
        return 0;
    }
};
exports.AppVersionService = AppVersionService;
exports.AppVersionService = AppVersionService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(app_version_policy_entity_1.AppVersionPolicy)),
    __metadata("design:paramtypes", [typeorm_2.Repository])
], AppVersionService);
//# sourceMappingURL=app-version.service.js.map