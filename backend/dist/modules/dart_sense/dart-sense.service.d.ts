export declare class DartSenseService {
    private readonly logger;
    detect(image: Express.Multer.File): Promise<{
        darts: any[];
    }>;
}
