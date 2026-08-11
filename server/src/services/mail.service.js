import nodemailer from "nodemailer";
import { env } from "../config/env.js";

export const transporter = nodemailer.createTransport({
  host: "smtp.gmail.com",
  port: 587,
  secure: false,
  auth: {
    user: env.smtpEmail,
    pass: env.smtpPass,
  },
});

transporter.verify((err, success) => {
  if (err) {
    console.log("VERIFY ERROR:", err);
  } else {
    console.log("SMTP READY");
  }
});

export async function sendOtpToAdmin({ name, email, otp }) {
  await transporter.sendMail({
    from: env.smtpEmail,
    to: env.adminEmail,
    subject: "New User Registration",
    html: `
      <h2>New User Registered</h2>
      <p><b>Name:</b> ${name}</p>
      <p><b>Email:</b> ${email}</p>
      <h1>${otp}</h1>
    `,
  });
}