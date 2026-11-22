import { handleOtp, otpCorsHeaders, type OtpBody } from "@/lib/otp-http";

export async function OPTIONS(request: Request) {
  return new Response(null, { status: 204, headers: otpCorsHeaders(request.headers.get("origin")) });
}

export async function POST(request: Request) {
  const headers = otpCorsHeaders(request.headers.get("origin"));
  let body: OtpBody = {};
  try {
    body = (await request.json()) as OtpBody;
  } catch {
    return Response.json({ ok: false, error: "invalid" }, { status: 400, headers });
  }
  const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  const result = await handleOtp(body, ip);
  return Response.json(result.body, { status: result.status, headers });
}
