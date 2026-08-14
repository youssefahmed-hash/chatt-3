import http from 'http';
import { env } from './config/env.js';
import { connectDB } from './config/database.js';
import { User } from './models/User.js';
import { createApp } from './app.js';
import { initSocket } from './realtime/socket.js';

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

  const app = createApp();
  const httpServer = http.createServer(app);

  initSocket(httpServer);

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
