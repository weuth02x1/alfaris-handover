const TTL_MS = 10 * 60 * 1000;
const WINDOW_MS = 15 * 60 * 1000;
const sends = new Map();

function rate(key, max) {
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

function cors(origin) {
  const allowed = origin && /^https:\/\/weuth02x1\.github\.io$|^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin)
    ? origin
    : "https://weuth02x1.github.io";
  return {
    "Access-Control-Allow-Origin": allowed,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    Vary: "Origin",
  };
}

async function hmac(secret, value) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function equal(a, b) {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i += 1) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}

export default {
  async fetch(request, env) {
    const headers = cors(request.headers.get("Origin"));
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
    if (request.method !== "POST") return Response.json({ ok: false, error: "invalid" }, { status: 405, headers });
    const secret = env.OTP_SECRET || env.SESSION_SECRET || env.RESEND_API_KEY;
    if (!secret || !env.RESEND_API_KEY) {
      return Response.json({ ok: false, error: "mailFailed" }, { status: 503, headers });
    }
    let body;
    try {
      body = await request.json();
    } catch {
      return Response.json({ ok: false, error: "invalid" }, { status: 400, headers });
    }
    const email = String(body.email || "").trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 160) {
      return Response.json({ ok: false, error: "invalid" }, { status: 400, headers });
    }
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";

    if (body.action === "send") {
      if (!rate(`e:${email}`, 5) || !rate(`ip:${ip}`, 20)) {
        return Response.json({ ok: false, error: "slow" }, { status: 429, headers });
      }
      const code = String(Math.floor(Math.random() * 1_000_000)).padStart(6, "0");
      const exp = Date.now() + TTL_MS;
      const challenge = `${exp}.${await hmac(secret, `${email}:${code}:${exp}`)}`;
      const from = env.RESEND_FROM || "Alfaris Group <onboarding@resend.dev>";
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          from,
          to: [email],
          subject: "رمز الدخول لنظام تسليم المهام",
          text: `رمز الدخول: ${code}\nصالح لمدة 10 دقائق. لا تشاركه مع أحد.\n\nYour sign-in code: ${code}\nIt expires in 10 minutes.`,
        }),
      });
      if (!response.ok) return Response.json({ ok: false, error: "mailFailed" }, { status: 502, headers });
      return Response.json({ ok: true, challenge }, { headers });
    }

    if (body.action === "verify") {
      const code = String(body.code || "").trim();
      const challenge = String(body.challenge || "");
      const dot = challenge.indexOf(".");
      const exp = Number(challenge.slice(0, dot));
      const hash = challenge.slice(dot + 1);
      if (!/^\d{6}$/.test(code) || !hash || !Number.isFinite(exp)) {
        return Response.json({ ok: false, error: "badCode" }, { status: 400, headers });
      }
      if (Date.now() > exp) return Response.json({ ok: false, error: "expired" }, { status: 400, headers });
      if (!rate(`v:${email}`, 8)) return Response.json({ ok: false, error: "slow" }, { status: 429, headers });
      const expected = await hmac(secret, `${email}:${code}:${exp}`);
      if (!equal(expected, hash)) return Response.json({ ok: false, error: "badCode" }, { status: 400, headers });
      return Response.json({ ok: true }, { headers });
    }

    return Response.json({ ok: false, error: "invalid" }, { status: 400, headers });
  },
};
