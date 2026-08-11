import { asyncHandler } from "../utils/asyncHandler.js";
import { sendOtpToAdmin } from "../services/mail.service.js";

export const testMail = asyncHandler(async (req, res) => {
  const otp = Math.floor(100000 + Math.random() * 900000).toString();

  await sendOtpToAdmin({
    name: "Test User",
    email: "test@test.com",
    otp,
  });

  res.json({
    message: "Mail sent successfully",
    otp,
  });
});