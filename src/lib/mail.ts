import "server-only";
import nodemailer from "nodemailer";
import { mutate, readDb } from "@/lib/db";
import type { EmailMessage } from "@/lib/types";

export function mailConfigured() {
  return Boolean(process.env.RESEND_API_KEY || (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS));
}

/** Sends one message. Resend first, then company SMTP. Returns false when neither is configured. */
export async function deliver(message: { to: string; subject: string; text: string }) {
  const to = message.to.trim();
  if (!/^[^\s@,;]+@[^\s@,;]+\.[^\s@,;]+$/.test(to)) return false;
  if (process.env.RESEND_API_KEY) {
    try {
      if (await deliverWithResend({ ...message, to })) return true;
    } catch {
      /* fall through to SMTP */
    }
  }
  if (!(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS)) return false;
  const port = Number(process.env.SMTP_PORT || 587);
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port,
    secure: port === 465,
    connectionTimeout: 5_000,
    greetingTimeout: 5_000,
    socketTimeout: 8_000,
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
  });
  await transporter.sendMail({
    from: process.env.SMTP_FROM || process.env.SMTP_USER,
    to,
    subject: message.subject,
    text: message.text,
  });
  return true;
}

async function deliverWithResend(message: { to: string; subject: string; text: string }) {
  const from = process.env.RESEND_FROM || "Alfaris Group <onboarding@resend.dev>";
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    signal: AbortSignal.timeout(8_000),
    headers: {
      Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [message.to],
      subject: message.subject,
      text: message.text,
    }),
  });
  if (!response.ok) {
    console.error("Resend rejected the message", response.status);
    return false;
  }
  return true;
}

/** Pushes pending outbox messages to company email. Unconfigured mail stays in the outbox. */
export async function flushOutbox() {
  const pending = (await readDb()).outbox.filter((m) => !m.delivered);
  for (const message of pending) {
    await sendAndMark(message);
  }
}

async function sendAndMark(message: EmailMessage) {
  const text = [message.body, message.link].filter(Boolean).join("\n\n");
  try {
    const sent = await deliver({ to: message.to, subject: message.subject, text });
    if (!sent) return;
    await mutate((db) => {
      const row = db.outbox.find((item) => item.id === message.id);
      if (row) row.delivered = true;
    });
  } catch (error) {
    console.error("Email delivery failed", message.to, error instanceof Error ? error.message : "unknown");
  }
}
