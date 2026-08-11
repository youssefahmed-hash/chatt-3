import { Router } from 'express';

import {
  register,
  login,
  me,
  verifyUserOtp,
  registerSchema,
  loginSchema,
  verifyOtpSchema,
} from '../controllers/auth.controller.js';

import { validate } from '../middleware/validate.js';
import { protect } from '../middleware/auth.js';
import { deleteMessage } from "../controllers/message.controller.js";

const router = Router();

// Register
router.post(
  '/register',
  validate(registerSchema),
  register,
);

// Verify OTP
router.post(
  '/verify',
  validate(verifyOtpSchema),
  verifyUserOtp,
);

// Login
router.post(
  '/login',
  validate(loginSchema),
  login,
);

// Current User
router.get(
  '/me',
  protect,
  me,
);

// Delete Message
router.delete(
  '/messages/:messageId',
  protect,
  (req, res, next) => {
    console.log('DELETE MESSAGE HIT');
    next();
  },
  deleteMessage,
);

export default router;