import { Repository } from 'typeorm';
import { AppVersionPolicy } from './entities/app-version-policy.entity';
type Platform = 'android' | 'ios';
type VersionStatus = 'force_update' | 'soft_update' | 'up_to_date';
export declare class AppVersionService {
    private readonly repo;
    constructor(repo: Repository<AppVersionPolicy>);
    getPolicyForClient(platformRaw: string, appVersion?: string, appBuildRaw?: string): Promise<{
        platform: Platform;
        min_version: string;
        recommended_version: string;
        min_build: number;
        recommended_build: number;
        store_url_android: string | null;
        store_url_ios: string | null;
        message_force_update: string;
        message_soft_update: string;
        status: VersionStatus;
        ttl_seconds: number;
        server_time: string;
    }>;
    private normalizePlatform;
    private resolveStatus;
    private normalizeBuild;
    private normalizeVersion;
    private compareVersions;
}
export {};
