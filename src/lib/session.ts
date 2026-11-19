import "server-only";
import { createHmac, timingSafeEqual } from "crypto";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { sessionKey } from "@/lib/db";
import { getPerson } from "@/lib/people";
import type { Employee } from "@/lib/types";

const COOKIE = "hs_session";
const MAX_AGE = 60 * 60 * 8;

async function sign(value: string) {
  return createHmac("sha256", await sessionKey()).update(value).digest("base64url");
}

export async function startSession(employeeId: string) {
  const exp = Math.floor(Date.now() / 1000) + MAX_AGE;
  const payload = `${employeeId}.${exp}`;
  (await cookies()).set(COOKIE, `${payload}.${await sign(payload)}`, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: MAX_AGE,
  });
}

export async function endSession() {
  (await cookies()).delete(COOKIE);
}

export async function currentUser(): Promise<Employee | null> {
  const raw = (await cookies()).get(COOKIE)?.value;
  if (!raw) return null;
  const parts = raw.split(".");
  if (parts.length !== 3) return null;
  const [id, exp, sig] = parts;
  const expected = Buffer.from(await sign(`${id}.${exp}`));
  const given = Buffer.from(sig);
  if (expected.length !== given.length || !timingSafeEqual(expected, given)) return null;
  if (Number(exp) < Date.now() / 1000) return null;
  return getPerson(id);
}

export async function requireUser(next?: string): Promise<Employee> {
  const user = await currentUser();
  if (!user) redirect(next ? `/login?next=${encodeURIComponent(next)}` : "/login");
  return user;
}
