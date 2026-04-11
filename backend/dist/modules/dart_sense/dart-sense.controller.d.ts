import { DartSenseService } from './dart-sense.service';
export declare class DartSenseController {
    private readonly dartSenseService;
    constructor(dartSenseService: DartSenseService);
    detect(file?: Express.Multer.File): Promise<{
        darts: any[];
    }>;
    detectBatch(files?: Express.Multer.File[], minOccurrences?: string, maxFrames?: string): Promise<{
        darts: any[];
        frames: any[];
        framesProcessed: number;
        minOccurrences: number;
    }>;
    feedback(file?: Express.Multer.File, zone?: string, multiplier?: string, source?: string, note?: string): Promise<{
        sample: object | null;
        message: string;
    }>;
}
