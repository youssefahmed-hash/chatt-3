import nodemailer from "nodemailer";
import { env } from "../config/env.js";
import { SystemSetting } from "../models/SystemSetting.js";

// Helper to load dynamic configuration with environment fallback
export async function getSmtpConfig() {
  const emailSetting = await SystemSetting.findByPk("SMTP_EMAIL");
  const passSetting = await SystemSetting.findByPk("SMTP_PASS");
  const adminEmailSetting = await SystemSetting.findByPk("ADMIN_EMAIL");

  return {
    smtpEmail: emailSetting?.value || env.smtpEmail,
    smtpPass: passSetting?.value || env.smtpPass,
    adminEmail: adminEmailSetting?.value || env.adminEmail,
  };
}

// Dynamically construct transporter
export async function createDynamicTransporter() {
  const config = await getSmtpConfig();
  return nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 587,
    secure: false,
    auth: {
      user: config.smtpEmail,
      pass: config.smtpPass,
    },
  });
}

// Test SMTP verification
export async function verifySmtpConnection() {
  try {
    const transporter = await createDynamicTransporter();
    await transporter.verify();
    return true;
  } catch (error) {
    console.error("SMTP verify connection error:", error.message);
    return false;
  }
}

export async function sendOtpToAdmin({ name, email, otp }) {
  try {
    const config = await getSmtpConfig();
    const transporter = await createDynamicTransporter();
    await transporter.sendMail({
      from: config.smtpEmail,
      to: config.adminEmail,
      subject: "New User Registration",
      html: `
        <h2>New User Registered</h2>
        <p><b>Name:</b> ${name}</p>
        <p><b>Email:</b> ${email}</p>
        <h1>${otp}</h1>
      `,
    });
  } catch (error) {
    console.error("SMTP send error:", error.message);
    throw new Error("Unable to send email. Please check the server SMTP configuration.");
  }
}

export async function sendTestMail(targetEmail, testOtp) {
  try {
    const config = await getSmtpConfig();
    const transporter = await createDynamicTransporter();
    await transporter.sendMail({
      from: config.smtpEmail,
      to: targetEmail,
      subject: "Chatt Self-Hosted SMTP Test",
      html: `
        <h2>SMTP Test Successful</h2>
        <p>Your self-hosted server SMTP settings are configured correctly.</p>
        <p>Here is your test OTP:</p>
        <h1>${testOtp}</h1>
      `,
    });
  } catch (error) {
    console.error("SMTP test send error:", error.message);
    throw new Error("Unable to send email. Please check the server SMTP configuration.");
  }
}