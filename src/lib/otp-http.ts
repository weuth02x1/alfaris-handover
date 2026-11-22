import { createHmac, randomInt, timingSafeEqual } from "crypto";
import { deliver, mailConfigured } from "@/lib/mail";

const WINDOW_MS = 15 * 60 * 1000;
const TTL_MS = 10 * 60 * 1000;

type Bucket = { at: number; n: number };
const sends = new Map<string, Bucket>();

function rate(key: string, max: number) {
  const now = Date.now();
  const bucket = sends.get(key);
  if (!bucket || now - bucket.at > WINDOW_MS) {
    sends.set(key, { at: now, n: 1 });
    return true;
  }
  if (bucket.n >= max) return false;
  bucket.n += 1;
  return true;
}

function secret() {
  return process.env.OTP_SECRET || process.env.SESSION_SECRET || process.env.RESEND_API_KEY || "";
}

function hmac(value: string) {
  return createHmac("sha256", secret()).update(value).digest("hex");
}

function safeEqual(a: string, b: string) {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

export type OtpBody = { action?: string; email?: string; code?: string; challenge?: string };

export async function handleOtp(input: OtpBody, ip: string) {
  const email = (input.email ?? "").trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 160) {
    return { status: 400, body: { ok: false as const, error: "invalid" } };
  }
  if (!secret() || !mailConfigured()) {
    return { status: 503, body: { ok: false as const, error: "mailFailed" } };
  }

  if (input.action === "send") {
    if (!rate(`e:${email}`, 5) || !rate(`ip:${ip}`, 20)) {
      return { status: 429, body: { ok: false as const, error: "slow" } };
    }
    const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
    const exp = Date.now() + TTL_MS;
    const challenge = `${exp}.${hmac(`${email}:${code}:${exp}`)}`;
    const text =
      `رمز الدخول: ${code}\nصالح لمدة 10 دقائق. لا تشاركه مع أحد.\n\nYour sign-in code: ${code}\nIt expires in 10 minutes.`;
    const sent = await deliver({ to: email, subject: "رمز الدخول لنظام تسليم المهام", text });
    if (!sent) return { status: 502, body: { ok: false as const, error: "mailFailed" } };
    return { status: 200, body: { ok: true as const, challenge } };
  }

  if (input.action === "verify") {
    const code = (input.code ?? "").trim();
    const challenge = input.challenge ?? "";
    const dot = challenge.indexOf(".");
    const exp = Number(challenge.slice(0, dot));
    const hash = challenge.slice(dot + 1);
    if (!/^\d{6}$/.test(code) || !hash || !Number.isFinite(exp)) {
      return { status: 400, body: { ok: false as const, error: "badCode" } };
    }
    if (Date.now() > exp) return { status: 400, body: { ok: false as const, error: "expired" } };
    if (!rate(`v:${email}`, 8)) return { status: 429, body: { ok: false as const, error: "slow" } };
    const expected = hmac(`${email}:${code}:${exp}`);
    if (!safeEqual(expected, hash)) return { status: 400, body: { ok: false as const, error: "badCode" } };
    return { status: 200, body: { ok: true as const } };
  }

  return { status: 400, body: { ok: false as const, error: "invalid" } };
}

export function otpCorsHeaders(origin: string | null) {
  const allowed = [
    "https://weuth02x1.github.io",
    "http://127.0.0.1:4317",
    "http://localhost:4317",
    "http://127.0.0.1:3847",
    "http://localhost:3847",
  ];
  const match = origin && (allowed.includes(origin) || /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin)) ? origin : allowed[0];
  return {
    "Access-Control-Allow-Origin": match,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    Vary: "Origin",
  };
}
