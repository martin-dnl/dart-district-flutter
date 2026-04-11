export declare class DartSenseService {
    private readonly logger;
    private get baseUrl();
    private appendFileToForm;
    detect(image: Express.Multer.File): Promise<{
        darts: any[];
    }>;
    detectBatch(images: Express.Multer.File[], minOccurrences?: number, maxFrames?: number): Promise<{
        darts: any[];
        frames: any[];
        framesProcessed: number;
        minOccurrences: number;
    }>;
    feedback(image: Express.Multer.File, zone: number, multiplier: number, source?: string, note?: string): Promise<{
        sample: object | null;
        message: string;
    }>;
}
