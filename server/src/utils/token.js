import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';

export function signToken(userId) {
  return jwt.sign({ sub: String(userId) }, env.jwtSecret, {
    expiresIn: env.jwtExpiresIn,
  });
}

// Returns the userId (string) or throws if the token is invalid/expired.
export function verifyToken(token) {
  const payload = jwt.verify(token, env.jwtSecret);
  return payload.sub;
}
