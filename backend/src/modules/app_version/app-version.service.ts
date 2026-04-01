import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AppVersionPolicy } from './entities/app-version-policy.entity';

type Platform = 'android' | 'ios';
type VersionStatus = 'force_update' | 'soft_update' | 'up_to_date';

@Injectable()
export class AppVersionService {
  constructor(
    @InjectRepository(AppVersionPolicy)
    private readonly repo: Repository<AppVersionPolicy>,
  ) {}

  async getPolicyForClient(platformRaw: string, appVersion?: string) {
    const platform = this.normalizePlatform(platformRaw);
    const policy = await this.repo.findOne({
      where: { platform, is_active: true },
      order: { updated_at: 'DESC' },
    });

    if (!policy) {
      throw new NotFoundException(`No active app version policy for ${platform}`);
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

  private normalizePlatform(value: string): Platform {
    const platform = (value ?? '').trim().toLowerCase();
    if (platform !== 'android' && platform !== 'ios') {
      throw new BadRequestException('platform must be android or ios');
    }
    return platform;
  }

  private resolveStatus(
    installedVersion: string | undefined,
    policy: AppVersionPolicy,
  ): VersionStatus {
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

  private normalizeVersion(raw: string): string {
    const clean = raw.trim().replace(/^v/i, '');
    const valid = /^\d+(\.\d+){0,3}$/.test(clean);
    if (!valid) {
      throw new BadRequestException(`Invalid version format: ${raw}`);
    }
    return clean;
  }

  private compareVersions(a: string, b: string): number {
    const aParts = a.split('.').map((part) => Number.parseInt(part, 10));
    const bParts = b.split('.').map((part) => Number.parseInt(part, 10));
    const maxLen = Math.max(aParts.length, bParts.length);

    for (let i = 0; i < maxLen; i += 1) {
      const left = aParts[i] ?? 0;
      const right = bParts[i] ?? 0;
      if (left < right) return -1;
      if (left > right) return 1;
    }

    return 0;
  }
}
