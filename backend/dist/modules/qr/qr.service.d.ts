import { Repository } from 'typeorm';
import { QrCode } from './entities/qr-code.entity';
export declare class QrService {
    private readonly repo;
    constructor(repo: Repository<QrCode>);
    generate(territoryId: string, venue: string): Promise<QrCode>;
    findByCode(code: string): Promise<QrCode>;
    findByTerritory(territoryId: string): Promise<QrCode[]>;
    deactivate(id: string): Promise<QrCode>;
}
