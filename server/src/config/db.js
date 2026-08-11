import mongoose from 'mongoose';
import { env } from './env.js';

export async function connectDB() {
  mongoose.set('strictQuery', true);

  try {
    await mongoose.connect(env.mongoUri);
    // eslint-disable-next-line no-console
    console.log('✅ MongoDB connected');
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('❌ MongoDB connection error:', err.message);
    process.exit(1);
  }

  mongoose.connection.on('disconnected', () => {
    // eslint-disable-next-line no-console
    console.warn('⚠️  MongoDB disconnected');
  });
}
