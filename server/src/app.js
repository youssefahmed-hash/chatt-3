import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import { env, isProd } from './config/env.js';
import authRoutes from './routes/auth.routes.js';
import userRoutes from './routes/user.routes.js';
import conversationRoutes from './routes/conversation.routes.js';
import { notFound, errorHandler } from './middleware/error.js';
import uploadRoutes from './routes/upload.routes.js';
import callRoutes from './routes/call.routes.js';
import path from 'path';
import testRoutes from './routes/test.routes.js';
export function createApp() {
  const app = express();

  app.use(cors({ origin: env.corsOrigin }));
  app.use(express.json());
  app.use('/uploads', express.static(path.resolve('uploads')));
  if (!isProd) app.use(morgan('dev'));

  // Health check.
  app.get('/health', (_req, res) => res.json({ status: 'ok' }));

  // API routes.
  app.use('/api/auth', authRoutes);
  app.use('/api/users', userRoutes);
  app.use('/api/conversations', conversationRoutes);
  app.use('/api/calls', callRoutes);
  app.use('/api/test', testRoutes);

  // 404 + central error handler (must be last).
  app.use(notFound);
  app.use(errorHandler);

  // Upload Image
  app.use('/api/upload', uploadRoutes);
  return app;
}
