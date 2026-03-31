"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ApiResponse = void 0;
class ApiResponse {
    static ok(data) {
        const r = new ApiResponse();
        r.success = true;
        r.data = data;
        r.error = null;
        return r;
    }
    static fail(error) {
        const r = new ApiResponse();
        r.success = false;
        r.data = null;
        r.error = error;
        return r;
    }
}
exports.ApiResponse = ApiResponse;
//# sourceMappingURL=api-response.dto.js.map