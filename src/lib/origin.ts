import "server-only";
import { headers } from "next/headers";

/** A host we are willing to put in an email link. Forwarded headers are ignored. */
function safeHost(raw: string | null) {
  if (!raw) return null;
  const host = raw.split(",")[0]?.trim().toLowerCase() ?? "";
  if (!/^[a-z0-9.-]{1,253}(?::\d{1,5})?$/.test(host)) return null;
  if (host.startsWith(".") || host.includes("..")) return null;
  return host;
}

/** Origin used inside emails. Comes from APP_BASE_URL, otherwise the request Host, never from a forwarded-host header. */
export async function appOrigin() {
  const configured = process.env.APP_BASE_URL;
  if (configured) {
    try {
      const url = new URL(configured);
      if (url.protocol === "http:" || url.protocol === "https:") return url.origin;
    } catch {
      /* ignore a malformed setting and fall through */
    }
  }
  const host = safeHost((await headers()).get("host"));
  if (!host) return "http://127.0.0.1:4317";
  const name = host.replace(/:\d+$/, "");
  const local = name === "localhost" || name === "127.0.0.1";
  return `${local ? "http" : "https"}://${host}`;
}
