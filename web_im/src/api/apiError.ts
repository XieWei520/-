export interface ApiErrorOptions {
  status?: number;
  code?: number;
  retryable?: boolean;
  unauthorized?: boolean;
}

export class ApiError extends Error {
  readonly status?: number;
  readonly code?: number;
  readonly retryable: boolean;
  readonly unauthorized: boolean;

  constructor(message: string, options: ApiErrorOptions = {}) {
    super(message);
    this.name = 'ApiError';
    this.status = options.status;
    this.code = options.code;
    this.unauthorized =
      options.unauthorized ?? (options.status === 401 || options.status === 403 || options.code === 401);
    this.retryable = options.retryable ?? (!this.unauthorized && (!options.status || options.status >= 500));
  }
}

export function toUserMessage(error: unknown, fallback: string): string {
  if (error instanceof ApiError && error.message.trim()) return error.message;
  if (error instanceof Error && error.message.trim()) return error.message;
  return fallback;
}
