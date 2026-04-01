import { AppVersionService } from './app-version.service';
export declare class AppVersionController {
    private readonly appVersionService;
    constructor(appVersionService: AppVersionService);
    getVersionPolicy(platform: string, appVersion?: string): Promise<{
        platform: "android" | "ios";
        min_version: string;
        recommended_version: string;
        store_url_android: string | null;
        store_url_ios: string | null;
        message_force_update: string;
        message_soft_update: string;
        status: "force_update" | "soft_update" | "up_to_date";
        ttl_seconds: number;
        server_time: string;
    }>;
}
