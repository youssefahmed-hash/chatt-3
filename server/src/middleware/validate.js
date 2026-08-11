import { ApiError } from '../utils/ApiError.js';

// Validates req.body against a zod schema and replaces it with the parsed
// (typed, trimmed) result. Throws a 422 with field details on failure.
export const validate = (schema) => (req, _res, next) => {
  const result = schema.safeParse(req.body);
  if (!result.success) {
    const details = result.error.issues.map((i) => ({
      field: i.path.join('.'),
      message: i.message,
    }));
    return next(new ApiError(422, 'Validation failed', details));
  }
  req.body = result.data;
  next();
};
