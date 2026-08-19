import fs from 'fs';
import path from 'path';
import webpush from 'web-push';
import { Device } from '../models/Device.js';
import { env } from '../config/env.js';

// VAPID keys are generated once and cached on disk (or provided via env),
// so the Web Push integration works out of the box with zero external setup.
const VAPID_FILE = path.resolve('data/vapid.json');

let vapidCache = null;

export function getVapidKeys() {
  if (vapidCache) return vapidCache;

  if (env.vapidPublicKey && env.vapidPrivateKey) {
    vapidCache = {
      publicKey: env.vapidPublicKey,
      privateKey: env.vapidPrivateKey,
      subject: env.vapidSubject,
    };
    return vapidCache;
  }

  if (fs.existsSync(VAPID_FILE)) {
    try {
      vapidCache = JSON.parse(fs.readFileSync(VAPID_FILE, 'utf8'));
      return vapidCache;
    } catch (_) {
      // regenerate below
    }
  }

  const keys = webpush.generateVAPIDKeys();
  vapidCache = {
    publicKey: keys.publicKey,
    privateKey: keys.privateKey,
    subject:
      env.vapidSubject ||
      'mailto:chatt-notifications@localhost',
  };
  fs.mkdirSync(path.dirname(VAPID_FILE), { recursive: true });
  fs.writeFileSync(VAPID_FILE, JSON.stringify(vapidCache, null, 2));
  return vapidCache;
}

function configureWebpush() {
  const { publicKey, privateKey, subject } = getVapidKeys();
  webpush.setVapidDetails(subject, publicKey, privateKey);
}

// Send a push notification to every registered device of the given users.
// Only online-aware sockets are excluded by the caller; a device that is
// foregrounded on mobile will show the local notification instead, so a
// duplicate is acceptable (the OS collapses by tag when suitable).
export async function sendPushToUsers(userIds, { title, body, data = {} }) {
  if (!userIds || !userIds.length) return;

  configureWebpush();

  const devices = await Device.findAll({
    where: { userId: userIds },
  });

  for (const device of devices) {
    try {
      if (device.platform === 'web') {
        const subscription = JSON.parse(device.token);
        await webpush.sendNotification(
          subscription,
          JSON.stringify({
            title: title || 'Chatt',
            body: body || '',
            data,
          }),
        );
      }
      // android / ios native push requires FCM service-account credentials;
      // the registration flow is ready and documented via FCM once the
      // server-side credentials (GOOGLE_APPLICATION_CREDENTIALS) exist.
    } catch (err) {
      // 404/410 = subscription expired; drop it so we stop bothering the
      // browser with dead endpoints.
      if (err.statusCode === 404 || err.statusCode === 410) {
        await device.destroy().catch(() => {});
      } else {
        console.error('Push send error:', err.statusCode || err.message);
      }
    }
  }
}

// (Re)register a device token for the current user. Returns the VAPID public
// key so web clients can subscribe BEFORE sending their token.
export async function registerDevice({ userId, token, platform = 'web' }) {
  const existing = await Device.findOne({ where: { userId, token } });
  if (existing) {
    existing.platform = platform;
    await existing.save();
  } else {
    await Device.create({ userId, token, platform });
  }
  return { publicKey: getVapidKeys().publicKey };
}

export async function unregisterDevice({ userId, token }) {
  await Device.destroy({ where: { userId, token } });
}