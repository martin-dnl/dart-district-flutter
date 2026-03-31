import { Territory } from '../../territories/entities/territory.entity';
export declare class QrCode {
    id: string;
    territory_id: string;
    venue_name: string | null;
    code: string;
    is_active: boolean;
    created_at: Date;
    territory: Territory;
}
