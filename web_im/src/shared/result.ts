export type Result<T> = { ok: true; value: T } | { ok: false; error: Error };

export const ok = <T>(value: T): Result<T> => ({ ok: true, value });
export const err = (error: unknown): Result<never> => ({
  ok: false,
  error: error instanceof Error ? error : new Error(String(error)),
});
