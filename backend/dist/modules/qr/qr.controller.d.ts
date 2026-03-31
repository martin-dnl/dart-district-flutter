import { QrService } from './qr.service';
export declare class QrController {
    private readonly qrService;
    constructor(qrService: QrService);
    generate(body: {
        territory_id: string;
        venue: string;
    }): Promise<import("./entities/qr-code.entity").QrCode>;
    scan(code: string): Promise<import("./entities/qr-code.entity").QrCode>;
    findByTerritory(territoryId: string): Promise<import("./entities/qr-code.entity").QrCode[]>;
    deactivate(id: string): Promise<import("./entities/qr-code.entity").QrCode>;
}
