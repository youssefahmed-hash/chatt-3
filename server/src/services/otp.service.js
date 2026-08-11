import { Otp } from "../models/Otp.js";

export function generateOtp() {
  return Math.floor(
    100000 + Math.random() * 900000
  ).toString();
}

export async function createOtp(data) {

  await Otp.destroy({
    where: {
      email: data.email,
    },
  });

  const otp = generateOtp();

  return await Otp.create({

    ...data,

    otp,

    expiresAt: new Date(
      Date.now() + 5 * 60 * 1000,
    ),
  });
}

export async function verifyOtp(
  email,
  otp,
) {

  const row = await Otp.findOne({
    where: {
      email,
      otp,
    },
  });

  if (!row) {
    return null;
  }

  if (row.expiresAt < new Date()) {

    await row.destroy();

    return null;
  }

  return row;
}