export class ApiResponse<T> {
  success: boolean;
  data: T | null;
  error: string | null;

  static ok<T>(data: T): ApiResponse<T> {
    const r = new ApiResponse<T>();
    r.success = true;
    r.data = data;
    r.error = null;
    return r;
  }

  static fail<T = null>(error: string): ApiResponse<T> {
    const r = new ApiResponse<T>();
    r.success = false;
    r.data = null;
    r.error = error;
    return r;
  }
}
