import "server-only";
import { headers } from "next/headers";
import { getIdentity } from "../../cursor/identity";
import { isEmail, normalizeEmail } from "@/lib/people";

export type Viewer = { id: string; email: string };

export async function signedInViewer(): Promise<Viewer | null> {
  const identity = await getIdentity(await headers());
  if (!identity.verified || identity.kind === "key") return null;
  const email = normalizeEmail(identity.email);
  if (!isEmail(email)) return null;
  return { id: identity.sub, email };
}

export function ownsEmail(email: string, viewer: Viewer) {
  return normalizeEmail(email) === viewer.email;
}
