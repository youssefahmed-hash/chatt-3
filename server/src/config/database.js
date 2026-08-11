import { Sequelize } from 'sequelize';
import { env } from './env.js';

export const db = new Sequelize(env.db.name, env.db.user, env.db.password, {
  host: env.db.host,
  port: env.db.port,
  dialect: 'postgres',
  logging: false,
  pool: { max: 5, min: 0, acquire: 30000, idle: 10000 },
});

export async function connectDB() {
  try {
    await db.authenticate();
    console.log('✅ PostgreSQL connected');

    // Import all models first
    await import('../models/User.js');
    await import('../models/Conversation.js');
    await import('../models/Message.js');
    await import('../models/Otp.js');

    // Sync tables (creates tables if they don't exist)
    await db.sync({ alter: true });
    console.log('✅ Database synced');
  } catch (err) {
    console.error('❌ PostgreSQL connection error:', err.message);
    process.exit(1);
  }
}
