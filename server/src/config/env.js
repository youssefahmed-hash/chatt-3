import dotenv from 'dotenv';

dotenv.config();

function required(name) {
  const value = process.env[name];
  if (!value) {
    console.error(`❌ Missing required environment variable: ${name}`);
    process.exit(1);
  }
  return value;
}

export const env = {
  port: Number(process.env.PORT) || 4000,
  nodeEnv: process.env.NODE_ENV || 'development',
  corsOrigin: (process.env.CORS_ORIGIN || '*')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean)
    .includes('*')
    ? '*'
    : (process.env.CORS_ORIGIN || '*')
        .split(',')
        .map((o) => o.trim())
        .filter(Boolean),

  // PostgreSQL config
  db: {
    host: required('DB_HOST'),
    port: Number(process.env.DB_PORT) || 5432,
    name: required('DB_NAME'),
    user: required('DB_USER'),
    password: required('DB_PASSWORD'),
  },

  // JWT
  jwtSecret: required('JWT_SECRET'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '30d',

  // Mail
  smtpEmail: required('SMTP_EMAIL'),
  smtpPass: required('SMTP_PASS'),
  adminEmail: required('ADMIN_EMAIL'),

  // Web Push (VAPID). Optional: keys are generated once and cached in
  // data/vapid.json when not provided.
  vapidPublicKey: process.env.VAPID_PUBLIC_KEY || null,
  vapidPrivateKey: process.env.VAPID_PRIVATE_KEY || null,
  vapidSubject: process.env.VAPID_SUBJECT || null,
};

export const isProd = env.nodeEnv === 'production';

