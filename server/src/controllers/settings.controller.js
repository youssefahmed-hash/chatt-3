import { SystemSetting } from "../models/SystemSetting.js";
import { getSmtpConfig, sendTestMail, verifySmtpConnection } from "../services/mail.service.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";

// GET /api/settings
export const getSettings = asyncHandler(async (req, res) => {
  const config = await getSmtpConfig();
  
  res.json({
    email: config.smtpEmail,
    adminEmail: config.adminEmail,
    emailConfigured: !!config.smtpEmail && !!config.smtpPass,
  });
});

// PUT /api/settings
export const updateSettings = asyncHandler(async (req, res) => {
  const { email, password, adminEmail } = req.body;

  if (email !== undefined) {
    await SystemSetting.upsert({ key: "SMTP_EMAIL", value: email.trim() });
  }

  if (password !== undefined && password.trim() !== "") {
    await SystemSetting.upsert({ key: "SMTP_PASS", value: password.trim() });
  }

  if (adminEmail !== undefined) {
    await SystemSetting.upsert({ key: "ADMIN_EMAIL", value: adminEmail.trim() });
  }

  res.json({
    message: "Settings updated successfully",
  });
});

// POST /api/settings/test-otp
export const testOtp = asyncHandler(async (req, res) => {
  const { email } = req.body;
  const config = await getSmtpConfig();
  
  const targetEmail = email || config.adminEmail;
  if (!targetEmail) {
    throw new ApiError(400, "No target email specified and no administrator email configured");
  }

  // Generate a random 6-digit OTP
  const randomOtp = Math.floor(100000 + Math.random() * 900000).toString();

  try {
    await sendTestMail(targetEmail, randomOtp);
    res.json({
      message: `Test OTP successfully sent to ${targetEmail}`,
    });
  } catch (error) {
    throw new ApiError(500, `Failed to send test email: ${error.message}`);
  }
});
