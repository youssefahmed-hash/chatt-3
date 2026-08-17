import { z } from 'zod';
import { User } from '../models/User.js';
import { ApiError } from '../utils/ApiError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { signToken } from '../utils/token.js';

import { createOtp } from '../services/otp.service.js';
import { sendOtpToAdmin } from '../services/mail.service.js';
import { verifyOtp } from "../services/otp.service.js";

export const registerSchema = z.object({
  name: z.string().trim().min(2, 'Name must be at least 2 characters').max(60),
  email: z.string().trim().email('Invalid email'),
  password: z.string().min(6, 'Password must be at least 6 characters').max(128),
});

export const loginSchema = z.object({
  email: z.string().trim().email('Invalid email'),
  password: z.string().min(1, 'Password is required'),
});

export const verifyOtpSchema = z.object({
  email: z.string().email(),
  otp: z.string().length(6),
});

// POST /api/auth/register
export const register = asyncHandler(async (req, res) => {
  const { name, email, password } = req.body;

  const exists = await User.findOne({
    where: { email },
  });

  if (exists) {
    throw new ApiError(409, 'Email already in use');
  }

  const otpData = await createOtp({
    name,
    email,
    password,
  });

  await sendOtpToAdmin({
    name,
    email,
    otp: otpData.otp,
  });

  res.status(200).json({
    message: 'OTP sent',
    email,
  });
});

// POST /api/auth/login
export const login = asyncHandler(async (req, res) => {
  const { email, password } = req.body;

  const user = await User.findOne({ where: { email } });

  if (!user || !(await user.comparePassword(password))) {
    throw new ApiError(401, 'Invalid email or password');
  }

  const token = signToken(user.id);

  res.json({
    token,
    user: user.toJSON(),
  });
});

// GET /api/auth/me
export const me = asyncHandler(async (req, res) => {
  res.json({
    user: req.user.toJSON(),
  });
});

export const verifyUserOtp = asyncHandler(async (req, res) => {

  const { email, otp } = req.body;

  const otpRow = await verifyOtp(
    email,
    otp,
  );

  if (!otpRow) {
    throw new ApiError(
      400,
      "Invalid or expired OTP",
    );
  }

  const exists = await User.findOne({
    where: {
      email,
    },
  });

  if (exists) {
    throw new ApiError(
      409,
      "Email already exists",
    );
  }

  const user = await User.create({
    name: otpRow.name,
    email: otpRow.email,
    passwordHash: otpRow.password,
  });

  await otpRow.destroy();

  const token = signToken(user.id);

  res.status(201).json({

    token,

    user: user.toJSON(),

  });

});

// POST /api/auth/change-credentials
export const changeCredentials = asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  const user = req.user;

  if (user.role !== 'admin') {
    throw new ApiError(403, 'Only administrators can perform this action');
  }

  if (!email || !password) {
    throw new ApiError(400, 'Email and password are required');
  }

  // Check if email already in use
  if (email.trim().toLowerCase() !== user.email.toLowerCase()) {
    const exists = await User.findOne({ where: { email: email.trim().toLowerCase() } });
    if (exists) {
      throw new ApiError(409, 'Email/username already in use');
    }
    user.email = email.trim().toLowerCase();
  }

  if (password.length < 6) {
    throw new ApiError(400, 'Password must be at least 6 characters');
  }

  user.passwordHash = password;
  user.mustChangeCredentials = false;
  await user.save();

  res.json({
    message: 'Credentials updated successfully',
    user: user.toJSON(),
  });
});