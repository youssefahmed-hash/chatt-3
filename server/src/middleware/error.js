import { isProd } from '../config/env.js';
import { ApiError } from '../utils/ApiError.js';

// 404 fallback for unmatched routes.
export function notFound(req, _res, next) {
  next(new ApiError(404, `Route not found: ${req.method} ${req.originalUrl}`));
}

// Central error handler — every thrown/async error ends up here.
// eslint-disable-next-line no-unused-vars
export function errorHandler(err, _req, res, _next) {
  let statusCode = err.statusCode || 500;
  let message = err.message || 'Internal server error';
  let details = err.details;

  // Mongo duplicate key (e.g. email already registered).
  if (err.code === 11000) {
    statusCode = 409;
    const field = Object.keys(err.keyValue || {})[0] || 'field';
    message = `${field} already in use`;
  }

  // Mongoose validation error.
  if (err.name === 'ValidationError') {
    statusCode = 422;
    message = 'Validation failed';
    details = Object.values(err.errors).map((e) => ({
      field: e.path,
      message: e.message,
    }));
  }

  // Bad ObjectId in a route param.
  if (err.name === 'CastError') {
    statusCode = 400;
    message = `Invalid ${err.path}`;
  }

  if (statusCode >= 500 && !isProd) {
    // eslint-disable-next-line no-console
    console.error(err);
  }

  res.status(statusCode).json({
    error: message,
    ...(details ? { details } : {}),
  });
}
