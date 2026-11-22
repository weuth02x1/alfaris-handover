import "server-only";
import { createHash, randomInt, timingSafeEqual } from "crypto";
import { mutate, sessionKey } from "@/lib/db";
import { deliver, mailConfigured } from "@/lib/mail";
import { findByEmail, isEmail, normalizeEmail } from "@/lib/people";
import type { Viewer } from "@/lib/viewer";
import { supabase, supabaseConfigured } from "@/lib/supabase";

const TTL_MS = 10 * 60 * 1000;
const WINDOW_MS = 15 * 60 * 1000;
const SIGNUP_WINDOW_MS = 60 * 60 * 1000;
const MAX_SENDS = 5;
const MAX_CALLER_SENDS = 20;
const MAX_ATTEMPTS = 5;
const MAX_ROWS = 500;

export type OtpRequestResult =
  | { ok: true }
  | { ok: false; error: "notFound" | "invalid" | "slow" | "mailFailed" };

export type OtpVerifyResult = { ok: true; employeeId: string } | { ok: false; error: "notFound" | "badCode" | "expired" | "slow" };

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

function prune(
  db: {
    otps: { sentAt: string; active: boolean; expiresAt: string }[];
    otpSends: { bucket?: string; sentAt: string }[];
    otpGuards: { windowStart: string }[];
  },
  now: number,
) {
  const signups = db.otpSends
    .filter((item) => item.bucket === "signup" && now - new Date(item.sentAt).getTime() < SIGNUP_WINDOW_MS)
    .slice(-200);
  const rest = db.otpSends.filter((item) => item.bucket !== "signup" && fresh(item.sentAt, now)).slice(-MAX_ROWS);
  db.otpSends = [...signups, ...rest];
  db.otps = db.otps
    .filter((item) => fresh(item.sentAt, now) || (item.active && new Date(item.expiresAt).getTime() > now))
    .slice(-MAX_ROWS);
  db.otpGuards = db.otpGuards.filter((item) => fresh(item.windowStart, now)).slice(-MAX_ROWS);
}

export async function requestOtp(emailInput: string, viewer: Viewer): Promise<OtpRequestResult> {
  const email = normalizeEmail(emailInput);
  if (!isEmail(email) || !viewer.id.trim() || email !== viewer.email) return { ok: false, error: "invalid" };

  const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
  const codeHash = await hashCode(code);
  const sentAt = new Date().toISOString();
  const now = Date.now();
  const caller = viewer.id.trim();

  const allowed = await mutate((db) => {
    prune(db, now);
    const emailSends = db.otpSends.filter((item) => item.bucket === `e:${email}`).length;
    const callerSends = db.otpSends.filter((item) => item.bucket === `c:${caller}`).length;
    const guard = db.otpGuards.find((item) => item.email === email);
    const locked = Boolean(guard && guard.failures >= MAX_ATTEMPTS);
    if (emailSends >= MAX_SENDS || callerSends >= MAX_CALLER_SENDS || locked) return false;
    return true;
  });
  if (!allowed) return { ok: false, error: "slow" };

  const employee = await findByEmail(email);
  if (!employee) return { ok: false, error: "notFound" };

  const text = `رمز الدخول: ${code}\nصالح لمدة 10 دقائق. لا تشاركه مع أحد.\n\nYour sign-in code: ${code}\nIt expires in 10 minutes.`;
  let sent = false;
  if (mailConfigured()) {
    await rememberCode();
    try {
      sent = await deliver({ to: employee.email, subject: "رمز الدخول لنظام تسليم المهام", text });
    } catch {
      sent = false;
    }
    if (sent) return { ok: true };
    await forgetCode();
  }

  if (supabaseConfigured()) {
    await mutate((db) => {
      db.otpSends.push({ bucket: `e:${email}`, sentAt });
      db.otpSends.push({ bucket: `c:${caller}`, sentAt });
    });
    try {
      const client = supabase();
      const { error } = await client!.auth.signInWithOtp({
        email: employee.email,
        options: { shouldCreateUser: true },
      });
      sent = !error;
    } catch {
      sent = false;
    }
    if (sent) return { ok: true };
  }

  return { ok: false, error: "mailFailed" };

  async function rememberCode() {
    await mutate((db) => {
      db.otpSends.push({ bucket: `e:${email}`, sentAt });
      db.otpSends.push({ bucket: `c:${caller}`, sentAt });
      for (const challenge of db.otps) if (challenge.email === email) challenge.active = false;
      db.otps.push({
        employeeId: employee!.id,
        email,
        codeHash,
        expiresAt: new Date(now + TTL_MS).toISOString(),
        sentAt,
        active: true,
      });
    });
  }

  async function forgetCode() {
    await mutate((db) => {
      db.otps = db.otps.filter((challenge) => !(challenge.email === email && challenge.codeHash === codeHash));
      db.otpSends = db.otpSends.filter((item) => item.sentAt !== sentAt);
    });
  }
}

export async function verifyOtp(emailInput: string, code: string): Promise<OtpVerifyResult> {
  const email = normalizeEmail(emailInput);
  if (!isEmail(email)) return { ok: false, error: "badCode" };
  const employee = await findByEmail(email);
  if (!employee) return { ok: false, error: "badCode" };
  const given = code.replace(/\s/g, "");
  if (!/^\d{6}$/.test(given)) return { ok: false, error: "badCode" };
  const givenHash = await hashCode(given);
  const now = Date.now();

  const local = await mutate((db) => {
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
  if (local.ok) return local;
  if (local.error !== "expired" || !supabaseConfigured()) return local;
  try {
    const client = supabase();
    const { error } = await client!.auth.verifyOtp({ email: employee.email, token: given, type: "email" });
    if (!error) {
      await mutate((db) => {
        const current = db.otpGuards.find((item) => item.email === email);
        if (current) current.failures = 0;
      });
      return { ok: true, employeeId: employee.id };
    }
    const counted = await mutate((db) => {
      const current = db.otpGuards.find((item) => item.email === email);
      if (current) current.failures += 1;
      else db.otpGuards.push({ email, failures: 1, windowStart: new Date(now).toISOString() });
      return db.otpGuards.find((item) => item.email === email)?.failures ?? 1;
    });
    if (counted >= MAX_ATTEMPTS) return { ok: false, error: "slow" };
    return { ok: false, error: /expired/i.test(error.message) ? "expired" : "badCode" };
  } catch {
    return { ok: false, error: "badCode" };
  }
}
