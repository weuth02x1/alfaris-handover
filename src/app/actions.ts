"use server";

import { cookies, headers } from "next/headers";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { flushOutbox } from "@/lib/mail";
import { requestOtp, verifyOtp } from "@/lib/otp";
import { currentUser, endSession, startSession } from "@/lib/session";
import { EXIT_REASONS, type ExitReason } from "@/lib/types";
import {
  acceptTask,
  hrDecision,
  initiateClearance,
  managerDecision,
  reassignTask,
  rejectTask,
  saveForm,
  WorkflowError,
  type TaskInput,
  type WorkflowErrorCode,
} from "@/lib/workflow";

export type ActionResult = { ok: true; message?: string } | { ok: false; error: WorkflowErrorCode };

async function baseUrl() {
  if (process.env.APP_BASE_URL) return process.env.APP_BASE_URL.replace(/\/$/, "");
  const h = await headers();
  const host = h.get("x-forwarded-host") ?? h.get("host") ?? "localhost";
  const proto = h.get("x-forwarded-proto") ?? (host.startsWith("localhost") || host.startsWith("127.") ? "http" : "https");
  return `${proto}://${host}`;
}

async function run(fn: () => Promise<unknown>): Promise<ActionResult> {
  try {
    await fn();
    await flushOutbox();
    revalidatePath("/", "layout");
    return { ok: true };
  } catch (e) {
    if (e instanceof WorkflowError) return { ok: false, error: e.code };
    throw e;
  }
}

async function actor() {
  const user = await currentUser();
  if (!user) throw new WorkflowError("notAllowed");
  return user;
}

const str = (fd: FormData, k: string) => String(fd.get(k) ?? "");

export async function requestOtpAction(identifier: string) {
  const result = await requestOtp(identifier);
  if (result.ok) await flushOutbox();
  return result;
}

export async function verifyOtpAction(identifier: string, code: string, next: string) {
  const result = await verifyOtp(identifier, code);
  if (!result.ok) return result;
  await startSession(result.employeeId);
  const target = /^\/(?![/\\])/.test(next) && !next.includes("\\") ? next : "/";
  return { ok: true as const, next: target };
}

export async function logout() {
  await endSession();
  redirect("/login");
}

export async function setLanguage(formData: FormData) {
  const lang = str(formData, "lang") === "en" ? "en" : "ar";
  (await cookies()).set("lang", lang, { path: "/", maxAge: 60 * 60 * 24 * 365, sameSite: "lax" });
  revalidatePath("/", "layout");
}

export async function startClearanceAction(ref: string, reason: string) {
  const exitReason: ExitReason | undefined = (EXIT_REASONS as readonly string[]).includes(reason)
    ? (reason as ExitReason)
    : undefined;
  return run(async () => initiateClearance(await actor(), ref, await baseUrl(), exitReason));
}

export async function saveHandoverAction(
  id: string,
  input: { generalNotes: string; tasks: TaskInput[] },
  submit: boolean,
) {
  return run(async () => saveForm(await actor(), id, input, submit, await baseUrl()));
}

export async function acceptTaskAction(id: string, taskId: string, note: string) {
  return run(async () => acceptTask(await actor(), id, taskId, note, await baseUrl()));
}

export async function rejectTaskAction(id: string, taskId: string, comment: string) {
  return run(async () => rejectTask(await actor(), id, taskId, comment, await baseUrl()));
}

export async function reassignTaskAction(id: string, taskId: string, assigneeId: string) {
  return run(async () => reassignTask(await actor(), id, taskId, assigneeId, await baseUrl()));
}

export async function managerDecisionAction(id: string, approve: boolean, comment: string) {
  return run(async () => managerDecision(await actor(), id, approve, comment, await baseUrl()));
}

export async function hrDecisionAction(id: string, approve: boolean, comment: string) {
  return run(async () => hrDecision(await actor(), id, approve, comment, await baseUrl()));
}
