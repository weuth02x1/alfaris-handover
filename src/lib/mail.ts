import "server-only";
import nodemailer from "nodemailer";
import { mutate, readDb } from "@/lib/db";
import type { EmailMessage } from "@/lib/types";

export function mailConfigured() {
  return Boolean(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS);
}

/** Sends one message. Returns false when company mail is not configured yet. */
export async function deliver(message: { to: string; subject: string; text: string }) {
  const to = message.to.trim();
  if (!/^[^\s@,;]+@[^\s@,;]+\.[^\s@,;]+$/.test(to)) return false;
  if (!mailConfigured()) return false;
  const port = Number(process.env.SMTP_PORT || 587);
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port,
    secure: port === 465,
    connectionTimeout: 10_000,
    greetingTimeout: 10_000,
    socketTimeout: 15_000,
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
