export declare class CreateClubDto {
    name: string;
    address?: string;
    city?: string;
    postal_code?: string;
    country?: string;
    latitude?: number;
    longitude?: number;
    dart_boards_count?: number;
    opening_hours?: Record<string, {
        open: string;
        close: string;
    }>;
    google_place_id?: string;
    code_iris?: string;
}
