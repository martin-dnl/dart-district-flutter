export declare class AppVersionPolicy {
    id: string;
    platform: 'android' | 'ios';
    min_version: string;
    recommended_version: string;
    min_build: number;
    recommended_build: number;
    store_url_android: string | null;
    store_url_ios: string | null;
    message_force_update: string;
    message_soft_update: string;
    is_active: boolean;
    created_at: Date;
    updated_at: Date;
}
