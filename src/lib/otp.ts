import "server-only";
import { createHash, randomInt, timingSafeEqual } from "crypto";
import { mutate, sessionKey } from "@/lib/db";
import { deliver } from "@/lib/mail";
import { findByEmail, isEmail, normalizeEmail } from "@/lib/people";

const TTL_MS = 10 * 60 * 1000;
const WINDOW_MS = 15 * 60 * 1000;
const MAX_SENDS = 3;
const MAX_ATTEMPTS = 5;
const MAX_GLOBAL_SENDS = 10;
const MAX_ROWS = 50;

export type OtpRequestResult =
  | { ok: true; maskedEmail: string }
  | { ok: false; error: "notFound" | "invalid" | "slow" | "mailFailed" };

export type OtpVerifyResult = { ok: true; employeeId: string } | { ok: false; error: "notFound" | "badCode" | "expired" | "slow" };

function maskEmail(email: string) {
  const [name, domain] = email.split("@");
  if (!domain) return email;
  return `${name.slice(0, 1)}***@${domain}`;
}

async function hashCode(code: string) {
  return createHash("sha256").update(`${code}.${await sessionKey()}`).digest("hex");
}

function sameHash(a: string, b: string) {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

function fresh(sentAt: string, now: number) {
  return now - new Date(sentAt).getTime() < WINDOW_MS;
}

function prune(db: { otps: { sentAt: string; active: boolean; expiresAt: string }[]; otpSends: { sentAt: string }[]; otpGuards: { windowStart: string }[] }, now: number) {
  db.otpSends = db.otpSends.filter((item) => fresh(item.sentAt, now)).slice(-MAX_ROWS);
  db.otps = db.otps
    .filter((item) => fresh(item.sentAt, now) || (item.active && new Date(item.expiresAt).getTime() > now))
    .slice(-MAX_ROWS);
  db.otpGuards = db.otpGuards.filter((item) => fresh(item.windowStart, now)).slice(-MAX_ROWS);
}

export async function requestOtp(emailInput: string): Promise<OtpRequestResult> {
  const email = normalizeEmail(emailInput);
  if (!isEmail(email)) return { ok: false, error: "invalid" };
  const employee = await findByEmail(email);
  if (!employee) return { ok: false, error: "notFound" };

  const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
  const codeHash = await hashCode(code);
  const sentAt = new Date().toISOString();
  const now = Date.now();

  const allowed = await mutate((db) => {
    prune(db, now);
    const emailSends = db.otpSends.filter((item) => item.bucket === `e:${email}`).length;
    const globalSends = db.otpSends.filter((item) => item.bucket === "g").length;
    const guard = db.otpGuards.find((item) => item.email === email);
    const locked = Boolean(guard && guard.failures >= MAX_ATTEMPTS);
    if (emailSends >= MAX_SENDS || globalSends >= MAX_GLOBAL_SENDS || locked) return false;
    for (const challenge of db.otps) {
      if (challenge.email === email) challenge.active = false;
    }
    db.otps.push({
      employeeId: employee.id,
      email,
      codeHash,
      expiresAt: new Date(now + TTL_MS).toISOString(),
      sentAt,
      active: true,
    });
    db.otpSends.push({ bucket: `e:${email}`, sentAt }, { bucket: "g", sentAt });
    return true;
  });
  if (!allowed) return { ok: false, error: "slow" };

  let sent = false;
  try {
    sent = await deliver({
      to: employee.email,
      subject: "رمز الدخول لنظام تسليم المهام",
      text: `رمز الدخول الخاص بك: ${code}\nصالح لمدة 10 دقائق. لا تشاركه مع أحد.\n\nYour sign-in code: ${code}\nIt expires in 10 minutes.`,
    });
  } catch {
    sent = false;
  }
  if (!sent) {
    await mutate((db) => {
      for (const challenge of db.otps) {
        if (challenge.email === email && challenge.codeHash === codeHash) challenge.active = false;
      }
    });
    return { ok: false, error: "mailFailed" };
  }

  return { ok: true, maskedEmail: maskEmail(employee.email) };
}

export async function verifyOtp(emailInput: string, code: string): Promise<OtpVerifyResult> {
  const email = normalizeEmail(emailInput);
  if (!isEmail(email)) return { ok: false, error: "notFound" };
  const employee = await findByEmail(email);
  if (!employee) return { ok: false, error: "notFound" };
  const given = code.replace(/\s/g, "");
  if (!/^\d{6}$/.test(given)) return { ok: false, error: "badCode" };
  const givenHash = await hashCode(given);
  const now = Date.now();

  return mutate((db) => {
    prune(db, now);
    const guard = db.otpGuards.find((item) => item.email === email);
    if (guard && !fresh(guard.windowStart, now)) {
      guard.failures = 0;
      guard.windowStart = new Date(now).toISOString();
    }
    if (guard && guard.failures >= MAX_ATTEMPTS) return { ok: false, error: "slow" } as const;

    const challenge = [...db.otps].reverse().find((item) => item.email === email && item.active);
    if (!challenge || new Date(challenge.expiresAt).getTime() < now) {
      return { ok: false, error: "expired" } as const;
    }
    if (!sameHash(challenge.codeHash, givenHash)) {
      const current = db.otpGuards.find((item) => item.email === email);
      if (current) current.failures += 1;
      else db.otpGuards.push({ email, failures: 1, windowStart: new Date(now).toISOString() });
      const failures = db.otpGuards.find((item) => item.email === email)?.failures ?? 1;
      if (failures >= MAX_ATTEMPTS) {
        for (const item of db.otps) if (item.email === email) item.active = false;
      }
      return { ok: false, error: "badCode" } as const;
    }
    challenge.active = false;
    const current = db.otpGuards.find((item) => item.email === email);
    if (current) current.failures = 0;
    return { ok: true, employeeId: employee.id } as const;
  });
}
