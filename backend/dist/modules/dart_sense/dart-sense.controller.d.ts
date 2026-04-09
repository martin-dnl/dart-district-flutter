import { DartSenseService } from './dart-sense.service';
export declare class DartSenseController {
    private readonly dartSenseService;
    constructor(dartSenseService: DartSenseService);
    detect(file?: Express.Multer.File): Promise<{
        darts: any[];
    }>;
}
