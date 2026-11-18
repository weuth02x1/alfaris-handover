"use server";

import { cookies, headers } from "next/headers";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { hr } from "@/lib/hr";
import { currentUser, demoLoginEnabled, endSession, startSession } from "@/lib/session";
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

export async function loginAs(formData: FormData) {
  if (!demoLoginEnabled()) throw new Error("Demo login disabled");
  const id = str(formData, "employeeId");
  const next = str(formData, "next");
  if (!(await hr().getEmployee(id))) throw new Error("Unknown employee");
  await startSession(id);
  redirect(/^\/(?![/\\])/.test(next) && !next.includes("\\") ? next : "/");
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

export async function startClearanceAction(ref: string) {
  return run(async () => initiateClearance(await actor(), ref, await baseUrl()));
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
