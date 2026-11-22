import { requireIdentity } from "../../../../cursor/identity";
import { requestOtp, verifyOtp } from "@/lib/otp";
import { isEmail, normalizeEmail } from "@/lib/people";

const noStore = { "Cache-Control": "private, no-store" };

type Body = { action?: string; email?: string; code?: string };

export async function POST(request: Request) {
  const identity = await requireIdentity(request);
  if (identity instanceof Response) {
    identity.headers.set("Cache-Control", "private, no-store");
    return identity;
  }
  if (identity.kind === "key") {
    return Response.json({ ok: false, error: "unauthorized" }, { status: 401, headers: noStore });
  }
  const viewerEmail = normalizeEmail(identity.email);
  if (!isEmail(viewerEmail)) {
    return Response.json({ ok: false, error: "invalid" }, { status: 400, headers: noStore });
  }
  const viewer = { id: identity.sub, email: viewerEmail };

  let body: Body = {};
  try {
    body = (await request.json()) as Body;
  } catch {
    return Response.json({ ok: false, error: "invalid" }, { status: 400, headers: noStore });
  }

  if (body.action === "send") {
    const result = await requestOtp(String(body.email ?? ""), viewer);
    const status = result.ok ? 200 : result.error === "slow" ? 429 : result.error === "notFound" ? 404 : result.error === "invalid" ? 400 : 502;
    return Response.json(result, { status, headers: noStore });
  }

  if (body.action === "verify") {
    const email = normalizeEmail(String(body.email ?? ""));
    if (email !== viewer.email) {
      return Response.json({ ok: false, error: "invalid" }, { status: 400, headers: noStore });
    }
    const result = await verifyOtp(email, String(body.code ?? ""));
    const status = result.ok ? 200 : result.error === "slow" ? 429 : 400;
    return Response.json(result.ok ? { ok: true } : result, { status, headers: noStore });
  }

  return Response.json({ ok: false, error: "invalid" }, { status: 400, headers: noStore });
}
