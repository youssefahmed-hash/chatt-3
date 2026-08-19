import { Sequelize } from 'sequelize';
import { env } from './env.js';
import { ensureEnumValues } from '../utils/ensureEnums.js';

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
    await import('../models/Reaction.js');
    await import('../models/Call.js');
    await import('../models/StarredMessage.js');
    await import('../models/SystemSetting.js');
    await import('../models/Device.js');

    // Upgrade existing Postgres enums before sync runs.
    await ensureEnumValues();

    // Sync tables (creates tables if they don't exist)
    await db.sync({ alter: true });
    console.log('✅ Database synced');

    // Register model associations after sync (needed for eager loading like
    // StarredMessage -> Message).
    await import('../config/associations.js');
  } catch (err) {
    console.error('❌ PostgreSQL connection error:', err.message);
    process.exit(1);
  }
}
