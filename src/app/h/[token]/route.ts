import { NextResponse, type NextRequest } from "next/server";
import { readDb } from "@/lib/db";
import { currentUser } from "@/lib/session";

/** Secure, time-bound link from the notification email. The user still has to be signed in as the addressee. */
export async function GET(request: NextRequest, ctx: RouteContext<"/h/[token]">) {
  const { token } = await ctx.params;
  const db = await readDb();
  const entry = db.tokens.find((x) => x.token === token);
  if (!entry || new Date(entry.expiresAt) < new Date()) {
    return NextResponse.redirect(new URL("/link-expired", request.url));
  }
  const target = `/handovers/${entry.handoverId}`;
  const user = await currentUser();
  if (user?.id === entry.employeeId) return NextResponse.redirect(new URL(target, request.url));
  const login = new URL("/login", request.url);
  login.searchParams.set("next", target);
  login.searchParams.set("for", entry.employeeId);
  return NextResponse.redirect(login);
}
