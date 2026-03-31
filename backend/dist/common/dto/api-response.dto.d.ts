export declare class ApiResponse<T> {
    success: boolean;
    data: T | null;
    error: string | null;
    static ok<T>(data: T): ApiResponse<T>;
    static fail<T = null>(error: string): ApiResponse<T>;
}
