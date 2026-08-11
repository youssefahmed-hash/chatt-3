// Wraps an async Express handler so thrown/rejected errors reach the
// central error middleware instead of crashing the process.
export const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);
