import http from 'http';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { env } from './config/env.js';
import { connectDB } from './config/database.js';
import { User } from './models/User.js';
import { createApp } from './app.js';
import { initSocket } from './realtime/socket.js';
import { startCleanupInterval } from './services/cleanup.service.js';

async function start() {
  await connectDB();

  // Presence is tracked per live socket; restarting the process leaves stale
  // online=true rows behind, so reset them before accepting connections.
  await User.update(
    { online: false },
    { where: { online: true } },
  ).catch((err) => {
    // eslint-disable-next-line no-console
    console.error('Failed to reset presence on boot:', err.message);
  });

  // Seed default admin user if none exist
  try {
    const adminCount = await User.count({ where: { role: 'admin' } });
    const credPath = path.resolve('initial_admin.json');

    if (adminCount === 0) {
      const randomId = crypto.randomBytes(3).toString('hex');
      const randomPassword = 'chatt-' + crypto.randomBytes(6).toString('hex');
      const email = `admin-${randomId}@chatt.local`.toLowerCase();

      await User.create({
        name: 'Administrator',
        email,
        passwordHash: randomPassword, // Will be hashed by User.js hook
        role: 'admin',
        mustChangeCredentials: true,
      });

      fs.writeFileSync(credPath, JSON.stringify({ email, password: randomPassword }, null, 2));
      console.log(`[Seed] Created initial administrator: ${email} (password written to initial_admin.json)`);
    } else {
      // Clean up the credential file if it exists since it's no longer needed
      if (fs.existsSync(credPath)) {
        fs.unlinkSync(credPath);
      }
    }
  } catch (err) {
    console.error('[Seed] Seeding administrator failed:', err.message);
  }

  const app = createApp();
  const httpServer = http.createServer(app);

  initSocket(httpServer);
  startCleanupInterval();

  httpServer.listen(env.port, () => {
    // eslint-disable-next-line no-console
    console.log(`🚀 chatt server running on http://localhost:${env.port} (${env.nodeEnv})`);
  });
}

start();

// Fail fast on unexpected errors so a process manager can restart cleanly.
process.on('unhandledRejection', (reason) => {
  // eslint-disable-next-line no-console
  console.error('Unhandled rejection:', reason);
  process.exit(1);
});
