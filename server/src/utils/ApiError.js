// Lightweight typed error so controllers can `throw new ApiError(404, '...')`
// and have the central error handler turn it into a clean JSON response.
export class ApiError extends Error {
  constructor(statusCode, message, details = undefined) {
    super(message);
    this.statusCode = statusCode;
    this.details = details;
    this.isOperational = true;
  }
}
