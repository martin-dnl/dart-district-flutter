export declare enum RegisterProvider {
    LOCAL = "local",
    GOOGLE = "google",
    APPLE = "apple",
    GUEST = "guest"
}
export declare class RegisterDto {
    display_name: string;
    email?: string;
    password?: string;
    provider?: RegisterProvider;
    provider_uid?: string;
    avatar_url?: string;
}
