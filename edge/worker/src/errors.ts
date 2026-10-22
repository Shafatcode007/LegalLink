export type ErrorStatus = 400 | 401 | 403 | 404 | 409 | 422 | 429;

export class ApiError extends Error {
  constructor(
    readonly status: ErrorStatus,
    readonly code: string,
    message: string,
    readonly messageBn: string,
    readonly retryable = false,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}
