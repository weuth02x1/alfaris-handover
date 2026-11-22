import "server-only";

/** This site's own address. Email links never trust the request Host header. */
const SITE_ORIGIN = "https://handover.alfarisgrp.com";

export async function appOrigin() {
  const configured = process.env.APP_BASE_URL;
  if (configured) {
    try {
      const url = new URL(configured);
      if (url.protocol === "http:" || url.protocol === "https:") return url.origin;
    } catch {
      /* a bad setting falls through to the site address */
    }
  }
  if (process.env.VERCEL_PROJECT_PRODUCTION_URL) {
    return `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`;
  }
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}`;
  if (process.env.NODE_ENV !== "production") return "http://127.0.0.1:4317";
  return SITE_ORIGIN;
}
