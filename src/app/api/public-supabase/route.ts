import { NextResponse } from "next/server";

/** Publishable client config for the static GitHub Pages app. Not a secret key. */
const PROJECT_URL = "https://sfshhcfjowiptefesqgp.supabase.co";

export async function GET() {
  const url = process.env.SUPABASE_URL?.trim() || PROJECT_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY?.trim() ?? "";
  if (!anonKey) {
    return NextResponse.json({ ok: false }, { status: 503, headers: { "Cache-Control": "no-store" } });
  }
  try {
    if (new URL(url).protocol !== "https:") {
      return NextResponse.json({ ok: false }, { status: 503, headers: { "Cache-Control": "no-store" } });
    }
  } catch {
    return NextResponse.json({ ok: false }, { status: 503, headers: { "Cache-Control": "no-store" } });
  }
  return NextResponse.json(
    { url, anonKey },
    {
      headers: {
        "Cache-Control": "public, max-age=300",
        "Access-Control-Allow-Origin": "*",
      },
    },
  );
}
