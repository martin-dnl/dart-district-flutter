"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeLimit = normalizeLimit;
function normalizeLimit(limit, defaultLimit, maxLimit = 100) {
    const parsedLimit = Number(limit);
    if (!Number.isFinite(parsedLimit) || parsedLimit <= 0) {
        return defaultLimit;
    }
    return Math.min(Math.trunc(parsedLimit), maxLimit);
}
//# sourceMappingURL=normalize-limit.js.map