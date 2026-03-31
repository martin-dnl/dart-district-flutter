export function normalizeLimit(
  limit: number | string | undefined,
  defaultLimit: number,
  maxLimit = 100,
) {
  const parsedLimit = Number(limit);

  if (!Number.isFinite(parsedLimit) || parsedLimit <= 0) {
    return defaultLimit;
  }

  return Math.min(Math.trunc(parsedLimit), maxLimit);
}