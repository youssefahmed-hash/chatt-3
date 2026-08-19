import fs from 'fs';
import path from 'path';
import webpush from 'web-push';
import { initializeApp, cert } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { Device } from '../models/Device.js';
import { env } from '../config/env.js';

// VAPID keys are generated once and cached on disk (or provided via env),
// so the Web Push integration works out of the box with zero external setup.
const VAPID_FILE = path.resolve('data/vapid.json');
const FIREBASE_SERVICE_ACCOUNT_PATHS = [
  process.env.FIREBASE_SERVICE_ACCOUNT,
  path.resolve('serviceAccountKey.json'),
  path.resolve('data/firebase-service-account.json'),
].filter(Boolean);

let vapidCache = null;
let fcmApp = null;
let fcmEnabledWarned = false;

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

// Lazy-load the Firebase admin app once a service-account key is available
// (server/serviceAccountKey.json, server/data/firebase-service-account.json
// or the FIREBASE_SERVICE_ACCOUNT env var). Until then phones simply keep
// their tokens registered and no FCM send happens (web push keeps working).
function getFcm() {
  if (fcmApp) return getMessaging(fcmApp);

  const accountFile = FIREBASE_SERVICE_ACCOUNT_PATHS.find((p) =>
    fs.existsSync(p),
  );
  if (!accountFile) {
    if (!fcmEnabledWarned) {
      fcmEnabledWarned = true;
      console.warn(
        '⚠️  Firebase service account not found — mobile FCM push is disabled. ' +
          'Place serviceAccountKey.json in the server folder (or set ' +
          'FIREBASE_SERVICE_ACCOUNT) to enable phone notifications.',
      );
    }
    return null;
  }

  try {
    const serviceAccount = JSON.parse(fs.readFileSync(accountFile, 'utf8'));
    fcmApp = initializeApp({
      credential: cert(serviceAccount),
    });
    return getMessaging(fcmApp);
  } catch (err) {
    console.error('Firebase init error:', err.message);
    return null;
  }
}

// Send a push notification to every registered device of the given users.
// Web devices receive Web Push (VAPID); Android/iOS devices receive FCM
// (notification + data payload so tapping opens the right conversation).
export async function sendPushToUsers(userIds, { title, body, data = {} }) {
  if (!userIds || !userIds.length) return;

  configureWebpush();

  const devices = await Device.findAll({
    where: { userId: userIds },
  });

  const fcm = getFcm();
  const fcmTokens = [];

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
      } else if (fcm) {
        fcmTokens.push(device);
      }
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

  if (!fcm || !fcmTokens.length) return;

  try {
    const response = await fcm.sendEachForMulticast({
      tokens: fcmTokens.map((d) => d.token),
      notification: {
        title: title || 'Chatt',
        body: body || '',
      },
      data: {
        ...Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)]),
        ),
        title: title || 'Chatt',
        body: body || '',
      },
    });

    // Drop tokens FCM no longer accepts (uninstalled / revoked).
    const failed = response.responses
      .map((r, i) => ({ r, d: fcmTokens[i] }))
      .filter(({ r }) => !r.success);
    for (const { r, d } of failed) {
      const code = r.error?.code || '';
      const tokenInvalid =
        code.includes('registration-token-not-registered') ||
        (code.includes('invalid-argument') &&
          String(r.error?.message || '').includes('token'));
      if (tokenInvalid) {
        await d.destroy().catch(() => {});
      }
    }
  } catch (err) {
    console.error('FCM multicast error:', err.message || err);
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