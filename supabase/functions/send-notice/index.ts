// Sends a workflow notice through Brevo. The browser only calls this
// function; the API key stays in the function secret BREVO_API_KEY.
// Sender must already be a verified Brevo sender (BREVO_SENDER).

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return new Response("method", { status: 405, headers: cors });

  const auth = req.headers.get("Authorization") ?? "";
  const apiKey = req.headers.get("apikey") ?? "";
  if (!auth.startsWith("Bearer ") || apiKey.length < 20) {
    return new Response("unauthorized", { status: 401, headers: cors });
  }

  let payload: { to?: string; subject?: string; body?: string };
  try {
    payload = await req.json();
  } catch {
    return new Response("invalid", { status: 400, headers: cors });
  }

  const to = (payload.to ?? "").trim().toLowerCase();
  const subject = (payload.subject ?? "").trim();
  const body = (payload.body ?? "").trim();
  const emailOk = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to) && !to.endsWith(".example");
  if (!emailOk || subject.length < 3 || subject.length > 180 || body.length < 3 || body.length > 4000) {
    return new Response("invalid", { status: 400, headers: cors });
  }

  const key = Deno.env.get("BREVO_API_KEY") ?? "";
  const sender = Deno.env.get("BREVO_SENDER") ?? "";
  if (!key || !sender) return new Response("mailer", { status: 503, headers: cors });

  const response = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: { "api-key": key, "Content-Type": "application/json", accept: "application/json" },
    body: JSON.stringify({
      sender: { name: "مجموعة الفارس", email: sender },
      to: [{ email: to }],
      subject,
      textContent: body,
    }),
  });
  if (!response.ok) return new Response("mailer", { status: 502, headers: cors });
  return new Response("{}", { status: 200, headers: { ...cors, "Content-Type": "application/json" } });
});
