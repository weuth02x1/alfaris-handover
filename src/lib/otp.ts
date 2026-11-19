import "server-only";
import { createHash, randomInt, randomUUID } from "crypto";
import { mutate, sessionKey } from "@/lib/db";
import { hr } from "@/lib/hr";
import { mailConfigured } from "@/lib/mail";
import type { Employee } from "@/lib/types";

const TTL_MS = 10 * 60 * 1000;
const MAX_ATTEMPTS = 5;
const WINDOW_MS = 15 * 60 * 1000;

export type OtpRequestResult =
  | { ok: true; maskedEmail: string; devCode?: string }
  | { ok: false; error: "notFound" | "slow" };

export type OtpVerifyResult = { ok: true; employeeId: string } | { ok: false; error: "notFound" | "badCode" | "expired" };

function maskEmail(email: string) {
  const [name, domain] = email.split("@");
  if (!domain) return email;
  const visible = name.slice(0, 1);
  return `${visible}***@${domain}`;
}

async function hashCode(code: string) {
  return createHash("sha256").update(`${code}.${await sessionKey()}`).digest("hex");
}

export function findEmployee(identifier: string, employees: Employee[]) {
  const value = identifier.trim().toLowerCase();
  return employees.find((e) => e.id === identifier.trim() || e.email.toLowerCase() === value) ?? null;
}

export async function requestOtp(identifier: string): Promise<OtpRequestResult> {
  const employees = await hr().listEmployees();
  const employee = findEmployee(identifier, employees);
  if (!employee) return { ok: false, error: "notFound" };

  const code = String(randomInt(0, 1_000_000)).padStart(6, "0");
  const codeHash = await hashCode(code);
  const sentAt = new Date().toISOString();

  const allowed = await mutate((db) => {
    const recent = db.otps.filter(
      (item) => item.employeeId === employee.id && Date.now() - new Date(item.sentAt).getTime() < WINDOW_MS,
    );
    if (recent.length >= 5) return false;
    db.otps = db.otps.filter((item) => item.employeeId !== employee.id);
    db.otps.push({ employeeId: employee.id, codeHash, expiresAt: new Date(Date.now() + TTL_MS).toISOString(), attempts: 0, sentAt });
    db.outbox.push({
      id: randomUUID(),
      to: employee.email,
      toEmployeeId: employee.id,
      subject: "رمز الدخول لنظام تسليم المهام | Sign-in code",
      body: `رمز الدخول الخاص بك: ${code}\nصالح لمدة 10 دقائق. لا تشاركه مع أحد.\n\nYour sign-in code: ${code}\nIt expires in 10 minutes.`,
      link: null,
      at: sentAt,
      kind: "otp",
      delivered: false,
    });
    return true;
  });
  if (!allowed) return { ok: false, error: "slow" };
  return { ok: true, maskedEmail: maskEmail(employee.email), ...(mailConfigured() ? {} : { devCode: code }) };
}

export async function verifyOtp(identifier: string, code: string): Promise<OtpVerifyResult> {
  const employees = await hr().listEmployees();
  const employee = findEmployee(identifier, employees);
  if (!employee) return { ok: false, error: "notFound" };
  const given = code.replace(/\s/g, "");
  if (!/^\d{6}$/.test(given)) return { ok: false, error: "badCode" };
  const givenHash = await hashCode(given);

  return mutate((db) => {
    const challenge = [...db.otps].reverse().find((item) => item.employeeId === employee.id);
    if (!challenge) return { ok: false, error: "expired" } as const;
    if (new Date(challenge.expiresAt).getTime() < Date.now() || challenge.attempts >= MAX_ATTEMPTS) {
      return { ok: false, error: "expired" } as const;
    }
    if (challenge.codeHash !== givenHash) {
      challenge.attempts += 1;
      return { ok: false, error: "badCode" } as const;
    }
    db.otps = db.otps.filter((item) => item !== challenge);
    return { ok: true, employeeId: employee.id } as const;
  });
}
