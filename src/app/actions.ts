"use server";

import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { safeNext } from "@/lib/safe-next";
import { flushOutbox } from "@/lib/mail";
import { appOrigin } from "@/lib/origin";
import { requestOtp, verifyOtp } from "@/lib/otp";
import { registerAccount, type SignupInput } from "@/lib/people";
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
  return appOrigin();
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

export async function requestOtpAction(email: string) {
  try {
    return await requestOtp(email);
  } catch {
    return { ok: false as const, error: "mailFailed" as const };
  }
}

export async function registerAction(input: SignupInput) {
  try {
    const created = await registerAccount({
      email: input.email,
      name: input.name,
      employeeNo: input.employeeNo,
      jobTitle: input.jobTitle,
      departmentId: input.departmentId,
    });
    if (!created.ok) {
      if (created.error === "emailTaken") return await requestOtp(input.email);
      return created;
    }
    return await requestOtp(created.employee.email);
  } catch {
    return { ok: false as const, error: "mailFailed" as const };
  }
}

export async function verifyOtpAction(email: string, code: string, next: string) {
  try {
    const result = await verifyOtp(email, code);
    if (!result.ok) return result;
    await startSession(result.employeeId);
    return { ok: true as const, next: safeNext(next) };
  } catch {
    return { ok: false as const, error: "badCode" as const };
  }
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
