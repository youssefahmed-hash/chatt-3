import { Router } from 'express';
import { protect } from '../middleware/auth.js';
import {
  registerDevice,
  unregisterDevice,
  getVapidKeys,
} from '../services/push.service.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';

const router = Router();

router.use(protect);

// GET /api/devices/config — VAPID public key for web push subscriptions.
router.get(
  '/config',
  asyncHandler(async (_req, res) => {
    res.json({ publicKey: getVapidKeys().publicKey, vapidSupported: true });
  }),
);

// POST /api/devices — register a push device (web subscription / native token).
router.post(
  '/',
  asyncHandler(async (req, res) => {
    const { token, platform } = req.body || {};
    if (!token || typeof token !== 'string' || !token.trim()) {
      throw new ApiError(400, 'Device token is required');
    }
    const result = await registerDevice({
      userId: req.user.id,
      token: token.trim(),
      platform: platform || 'web',
    });
    res.json(result);
  }),
);

// DELETE /api/devices — remove a push device (logout / subscription change).
router.delete(
  '/',
  asyncHandler(async (req, res) => {
    const { token } = req.body || {};
    if (!token) throw new ApiError(400, 'Device token is required');
    await unregisterDevice({ userId: req.user.id, token });
    res.json({ ok: true });
  }),
);

export default router;