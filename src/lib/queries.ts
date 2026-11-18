import "server-only";
import { readDb } from "@/lib/db";
import type { Employee, Handover } from "@/lib/types";

export function accessFor(user: Employee, h: Handover) {
  const isOwner = h.employee.id === user.id;
  const isManager = h.employee.managerId === user.id;
  const isHr = user.role === "hr";
  const isRecipient = h.tasks.some(
    (t) =>
      (t.assigneeId === user.id && t.status !== "draft") ||
      t.rejections.some((r) => r.recipientId === user.id),
  );
  return { isOwner, isManager, isHr, isRecipient, canView: isOwner || isManager || isHr || isRecipient };
}

export async function getHandoverFor(user: Employee, id: string) {
  const db = await readDb();
  const h = db.handovers.find((x) => x.id === id);
  if (!h) return null;
  const access = accessFor(user, h);
  if (!access.canView) return null;
  const audit = db.audit.filter((a) => a.handoverId === id).sort((a, b) => a.at.localeCompare(b.at));
  return { handover: h, access, audit };
}

export async function inboxFor(user: Employee) {
  const db = await readDb();
  const mine = db.handovers.filter((h) => h.employee.id === user.id);
  const toAccept = db.handovers.flatMap((h) =>
    h.status === "pending_acceptance"
      ? h.tasks.filter((t) => t.assigneeId === user.id && t.status === "pending").map((t) => ({ h, t }))
      : [],
  );
  const accepted = db.handovers.flatMap((h) =>
    h.tasks.filter((t) => t.assigneeId === user.id && t.status === "accepted").map((t) => ({ h, t })),
  );
  const managerQueue = db.handovers.filter(
    (h) => h.status === "pending_manager" && h.employee.managerId === user.id,
  );
  const hrQueue = user.role === "hr" ? db.handovers.filter((h) => h.status === "pending_hr") : [];
  return { mine, toAccept, accepted, managerQueue, hrQueue };
}
