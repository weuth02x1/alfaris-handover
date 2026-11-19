import "server-only";
import { createHash, randomBytes, randomUUID } from "crypto";
import { mutate } from "@/lib/db";
import { hr } from "@/lib/hr";
import { colleaguesFor, getPerson, listPeople } from "@/lib/people";
import { EXIT_REASONS, type AuditAction, type Database, type Employee, type ExitReason, type Handover, type HandoverTask } from "@/lib/types";

export type WorkflowErrorCode =
  | "notAllowed"
  | "commentRequired"
  | "notFound"
  | "assigneeRequired"
  | "titleRequired"
  | "sameAssignee"
  | "noTasks";

export class WorkflowError extends Error {
  constructor(public code: WorkflowErrorCode) {
    super(code);
  }
}

const LINK_TTL_HOURS = Number(process.env.LINK_TTL_HOURS || 72);

const now = () => new Date().toISOString();

function audit(db: Database, h: Handover, actorId: string, action: AuditAction, details = "") {
  db.audit.push({ id: randomUUID(), handoverId: h.id, at: now(), actorId, action, details });
}

function issueLink(db: Database, baseUrl: string, h: Handover, employeeId: string) {
  const token = randomBytes(24).toString("base64url");
  db.tokens.push({
    token,
    handoverId: h.id,
    employeeId,
    expiresAt: new Date(Date.now() + LINK_TTL_HOURS * 3600_000).toISOString(),
  });
  return `${baseUrl}/h/${token}`;
}

function notify(
  db: Database,
  baseUrl: string,
  h: Handover,
  to: Employee,
  subject: string,
  body: string,
) {
  const link = issueLink(db, baseUrl, h, to.id);
  db.outbox.push({
    id: randomUUID(),
    to: to.email,
    toEmployeeId: to.id,
    subject,
    body,
    link,
    at: now(),
    kind: "workflow",
    delivered: false,
  });
  db.outbox = db.outbox.slice(-100);
}

function find(db: Database, id: string) {
  const h = db.handovers.find((x) => x.id === id);
  if (!h) throw new WorkflowError("notFound");
  return h;
}

async function mustEmployee(id: string) {
  const e = await getPerson(id);
  if (!e) throw new WorkflowError("notFound");
  return e;
}

async function listHr() {
  return (await listPeople()).filter((e) => e.role === "hr");
}

/** HR starts clearance for an approved request: creates the form and emails the employee. */
export async function initiateClearance(actor: Employee, requestRef: string, baseUrl: string, reason?: ExitReason) {
  if (actor.role !== "hr") throw new WorkflowError("notAllowed");
  const req = (await hr().listApprovedRequests()).find((r) => r.ref === requestRef);
  if (!req) throw new WorkflowError("notFound");
  const emp = await mustEmployee(req.employeeId);
  const manager = emp.managerId ? await getPerson(emp.managerId) : null;

  return mutate((db) => {
    const existing = db.handovers.find((h) => h.requestRef === req.ref);
    if (existing) return existing.id;
    db.counter += 1;
    const h: Handover = {
      id: randomUUID(),
      number: `HO-${new Date().getFullYear()}-${String(db.counter).padStart(4, "0")}`,
      requestRef: req.ref,
      type: reason && (EXIT_REASONS as readonly string[]).includes(reason) ? reason : req.type,
      lastWorkingDay: req.startDate,
      returnDate: req.endDate,
      employee: {
        id: emp.id,
        nameAr: emp.nameAr,
        nameEn: emp.nameEn,
        jobTitleAr: emp.jobTitleAr,
        jobTitleEn: emp.jobTitleEn,
        departmentAr: emp.departmentAr,
        departmentEn: emp.departmentEn,
        sectionAr: emp.sectionAr,
        sectionEn: emp.sectionEn,
        managerId: emp.managerId,
        managerNameAr: manager?.nameAr ?? "",
        managerNameEn: manager?.nameEn ?? "",
      },
      status: "draft",
      generalNotes: "",
      tasks: [],
      lastReturn: null,
      managerApproval: null,
      hrApproval: null,
      initiatedById: actor.id,
      createdAt: now(),
      submittedAt: null,
      finalizedAt: null,
      documentHash: null,
      hrmsDocumentId: null,
    };
    db.handovers.push(h);
    audit(db, h, actor.id, "clearance_initiated", req.ref);
    notify(
      db,
      baseUrl,
      h,
      emp,
      `مطلوب: تعبئة نموذج تسليم المهام ${h.number} | Action required: handover form`,
      `بدأت الموارد البشرية إخلاء الطرف للطلب ${req.ref}. افتح الرابط الآمن، سجّل الدخول، وعبّئ نموذج تسليم المهام وحدد مستلم كل مهمة.\n\nHR has started clearance for ${req.ref}. Open the secure link, sign in, fill in your handover form and assign each task.`,
    );
    audit(db, h, "system", "link_sent", emp.email);
    return h.id;
  });
}

export interface TaskInput {
  id?: string;
  title: string;
  details: string;
  dueDate: string | null;
  assigneeId: string;
}

/** Employee saves or submits the form. Only allowed while the form is in the employee's hands. */
export async function saveForm(
  actor: Employee,
  id: string,
  input: { generalNotes: string; tasks: TaskInput[] },
  submit: boolean,
  baseUrl: string,
) {
  const colleagues = await colleaguesFor(actor.id);
  const colleagueIds = new Set(colleagues.map((c) => c.id));
  const manager = actor.managerId ? await getPerson(actor.managerId) : null;
  const hrUsers = await listHr();

  for (const task of input.tasks) {
    if (submit && !task.title.trim()) throw new WorkflowError("titleRequired");
    if (submit && !task.assigneeId) throw new WorkflowError("assigneeRequired");
    if (task.assigneeId && !colleagueIds.has(task.assigneeId)) throw new WorkflowError("notAllowed");
  }
  if (submit && input.tasks.length === 0) throw new WorkflowError("noTasks");

  return mutate((db) => {
    const h = find(db, id);
    if (h.employee.id !== actor.id) throw new WorkflowError("notAllowed");
    if (h.status !== "draft" && h.status !== "returned") throw new WorkflowError("notAllowed");

    const previous = new Map(h.tasks.map((t) => [t.id, t]));
    h.generalNotes = input.generalNotes;
    h.tasks = input.tasks.map((ti): HandoverTask => {
      const prev = ti.id ? previous.get(ti.id) : undefined;
      const unchanged =
        prev &&
        prev.title === ti.title &&
        prev.details === ti.details &&
        prev.dueDate === ti.dueDate &&
        prev.assigneeId === ti.assigneeId;
      if (prev && unchanged && prev.status === "accepted") return prev;
      return {
        id: prev?.id ?? randomUUID(),
        title: ti.title.trim(),
        details: ti.details.trim(),
        dueDate: ti.dueDate || null,
        assigneeId: ti.assigneeId,
        status: "draft",
        acceptedAt: null,
        acceptNote: null,
        rejections: prev?.rejections ?? [],
      };
    });

    if (!submit) {
      audit(db, h, actor.id, "form_saved");
      return h.id;
    }

    h.submittedAt = now();
    h.lastReturn = null;
    h.managerApproval = null;
    h.hrApproval = null;
    audit(db, h, actor.id, "form_submitted", `${h.tasks.length}`);

    for (const task of h.tasks) {
      if (task.status === "accepted") continue;
      task.status = "pending";
      const recipient = colleagues.find((c) => c.id === task.assigneeId)!;
      audit(db, h, actor.id, "task_assigned", `${task.title} → ${recipient.nameAr}`);
      notifyRecipient(db, baseUrl, h, task, recipient, actor);
    }
    advanceIfAllAccepted(db, baseUrl, h, manager, hrUsers);
    return h.id;
  });
}

function notifyRecipient(
  db: Database,
  baseUrl: string,
  h: Handover,
  task: HandoverTask,
  recipient: Employee,
  from: Employee,
) {
  notify(
    db,
    baseUrl,
    h,
    recipient,
    `${from.nameAr} أسند لك مهام، ادخل للموافقة`,
    `${from.nameAr} أسند لك مهام وتحتاج موافقتك.\nالمهمة: ${task.title}${task.details ? `\n${task.details}` : ""}\n\nادخل عبر الرابط للموافقة أو الرفض. الموقع ما يرسل إشعارات داخل المتصفح، والاعتماد يصير من الرابط في هذا الإيميل.\n\n${from.nameEn} assigned you a task and needs your approval: ${task.title}`,
  );
}

function advanceIfAllAccepted(
  db: Database,
  baseUrl: string,
  h: Handover,
  manager: Employee | null,
  hrUsers: Employee[],
) {
  if (!h.tasks.every((t) => t.status === "accepted")) {
    h.status = "pending_acceptance";
    return;
  }
  if (manager) {
    h.status = "pending_manager";
    notify(
      db,
      baseUrl,
      h,
      manager,
      `بانتظار اعتمادك: نموذج تسليم ${h.employee.nameAr} | Approval needed`,
      `قبل جميع المستلمين مهام ${h.employee.nameAr} في النموذج ${h.number}. راجع النموذج واعتمده أو أعده مع ذكر السبب.\n\nAll recipients accepted ${h.employee.nameEn}'s tasks (${h.number}). Please review and approve or return it.`,
    );
  } else {
    moveToHr(db, baseUrl, h, hrUsers);
  }
}

function moveToHr(db: Database, baseUrl: string, h: Handover, hrUsers: Employee[]) {
  h.status = "pending_hr";
  for (const u of hrUsers) {
    notify(
      db,
      baseUrl,
      h,
      u,
      `اعتماد نهائي مطلوب: ${h.number} | Final HR approval needed`,
      `اعتمد المدير المباشر نموذج تسليم ${h.employee.nameAr} (${h.number}). الاعتماد النهائي يصدر التقرير ويرفعه لملف الموظف.\n\n${h.number} for ${h.employee.nameEn} is ready for final HR approval.`,
    );
  }
}

export async function acceptTask(actor: Employee, id: string, taskId: string, note: string, baseUrl: string) {
  const owner = await mutatePeek(id);
  const manager = owner.employee.managerId ? await getPerson(owner.employee.managerId) : null;
  const hrUsers = await listHr();
  return mutate((db) => {
    const h = find(db, id);
    const task = h.tasks.find((t) => t.id === taskId);
    if (!task || task.assigneeId !== actor.id || task.status !== "pending" || h.status !== "pending_acceptance")
      throw new WorkflowError("notAllowed");
    task.status = "accepted";
    task.acceptedAt = now();
    task.acceptNote = note.trim() || null;
    audit(db, h, actor.id, "task_accepted", task.title);
    advanceIfAllAccepted(db, baseUrl, h, manager, hrUsers);
    return h.id;
  });
}

/** Recipient declines: the task goes back to the employee to choose someone else. */
export async function rejectTask(actor: Employee, id: string, taskId: string, comment: string, baseUrl: string) {
  if (!comment.trim()) throw new WorkflowError("commentRequired");
  const snapshot = await mutatePeek(id);
  const owner = await mustEmployee(snapshot.employee.id);
  return mutate((db) => {
    const h = find(db, id);
    const task = h.tasks.find((t) => t.id === taskId);
    if (!task || task.assigneeId !== actor.id || task.status !== "pending" || h.status !== "pending_acceptance")
      throw new WorkflowError("notAllowed");
    task.status = "rejected";
    task.rejections.push({ recipientId: actor.id, comment: comment.trim(), at: now() });
    audit(db, h, actor.id, "task_rejected", `${task.title}: ${comment.trim()}`);
    notify(
      db,
      baseUrl,
      h,
      owner,
      `رفض ${actor.nameAr} استلام مهمة | ${actor.nameEn} declined a task`,
      `رفض ${actor.nameAr} استلام المهمة "${task.title}".\nالسبب: ${comment.trim()}\nافتح النموذج واختر موظفاً آخر لهذه المهمة.\n\n${actor.nameEn} declined "${task.title}". Reason: ${comment.trim()}\nOpen the form and pick another employee.`,
    );
    return h.id;
  });
}

export async function reassignTask(actor: Employee, id: string, taskId: string, newAssigneeId: string, baseUrl: string) {
  const colleagues = await colleaguesFor(actor.id);
  const recipient = colleagues.find((c) => c.id === newAssigneeId);
  if (!recipient) throw new WorkflowError("assigneeRequired");
  return mutate((db) => {
    const h = find(db, id);
    if (h.employee.id !== actor.id || h.status !== "pending_acceptance") throw new WorkflowError("notAllowed");
    const task = h.tasks.find((t) => t.id === taskId);
    if (!task || task.status !== "rejected") throw new WorkflowError("notAllowed");
    if (task.rejections.some((r) => r.recipientId === newAssigneeId)) throw new WorkflowError("sameAssignee");
    task.assigneeId = newAssigneeId;
    task.status = "pending";
    audit(db, h, actor.id, "task_reassigned", `${task.title} → ${recipient.nameAr}`);
    notifyRecipient(db, baseUrl, h, task, recipient, actor);
    return h.id;
  });
}

export async function managerDecision(
  actor: Employee,
  id: string,
  approve: boolean,
  comment: string,
  baseUrl: string,
) {
  if (!approve && !comment.trim()) throw new WorkflowError("commentRequired");
  const snapshot = await mutatePeek(id);
  const owner = await mustEmployee(snapshot.employee.id);
  const hrUsers = await listHr();
  return mutate((db) => {
    const h = find(db, id);
    if (h.status !== "pending_manager" || h.employee.managerId !== actor.id) throw new WorkflowError("notAllowed");
    if (approve) {
      h.managerApproval = { byId: actor.id, at: now(), comment: comment.trim() || null };
      audit(db, h, actor.id, "manager_approved", comment.trim());
      moveToHr(db, baseUrl, h, hrUsers);
    } else {
      returnToEmployee(db, baseUrl, h, owner, actor, "manager", comment.trim());
    }
    return h.id;
  });
}

function returnToEmployee(
  db: Database,
  baseUrl: string,
  h: Handover,
  owner: Employee,
  actor: Employee,
  stage: "manager" | "hr",
  comment: string,
) {
  h.status = "returned";
  h.lastReturn = { stage, byId: actor.id, comment, at: now() };
  audit(db, h, actor.id, stage === "manager" ? "manager_rejected" : "hr_rejected", comment);
  notify(
    db,
    baseUrl,
    h,
    owner,
    `أُعيد نموذج التسليم ${h.number} للتعديل | Handover returned for correction`,
    `أعاد ${actor.nameAr} نموذج التسليم إليك.\nالسبب: ${comment}\nعدّل النموذج وأعد إرساله.\n\n${actor.nameEn} returned your handover form. Reason: ${comment}`,
  );
}

export function canonicalRecord(h: Handover) {
  return {
    number: h.number,
    requestRef: h.requestRef,
    type: h.type,
    lastWorkingDay: h.lastWorkingDay,
    returnDate: h.returnDate,
    employee: h.employee,
    generalNotes: h.generalNotes,
    tasks: h.tasks.map((t) => ({
      title: t.title,
      details: t.details,
      dueDate: t.dueDate,
      assigneeId: t.assigneeId,
      acceptedAt: t.acceptedAt,
      acceptNote: t.acceptNote,
    })),
    managerApproval: h.managerApproval,
    hrApproval: h.hrApproval,
    finalizedAt: h.finalizedAt,
  };
}

export async function hrDecision(actor: Employee, id: string, approve: boolean, comment: string, baseUrl: string) {
  if (actor.role !== "hr") throw new WorkflowError("notAllowed");
  if (!approve && !comment.trim()) throw new WorkflowError("commentRequired");
  const snapshot = await mutatePeek(id);
  const owner = await mustEmployee(snapshot.employee.id);

  const finalized = await mutate((db) => {
    const h = find(db, id);
    if (h.status !== "pending_hr") throw new WorkflowError("notAllowed");
    if (!approve) {
      returnToEmployee(db, baseUrl, h, owner, actor, "hr", comment.trim());
      return null;
    }
    h.hrApproval = { byId: actor.id, at: now(), comment: comment.trim() || null };
    h.status = "approved";
    h.finalizedAt = now();
    h.documentHash = createHash("sha256").update(JSON.stringify(canonicalRecord(h))).digest("hex");
    audit(db, h, actor.id, "hr_approved", comment.trim());
    audit(db, h, "system", "document_generated", h.documentHash.slice(0, 16));
    notify(
      db,
      baseUrl,
      h,
      owner,
      `اكتمل تسليم المهام ${h.number} | Handover completed`,
      `تم الاعتماد النهائي لنموذج تسليم المهام وإصدار التقرير وحفظه في ملفك بنظام الموارد البشرية.\n\nYour handover was approved and the final report is filed on your HR record.`,
    );
    return structuredClone(h);
  });

  if (finalized) {
    const { documentId } = await hr().uploadFinalDocument({
      employeeId: finalized.employee.id,
      handoverNumber: finalized.number,
      requestRef: finalized.requestRef,
      fileName: `${finalized.number}.json`,
      contentHash: finalized.documentHash!,
      record: canonicalRecord(finalized),
    });
    await mutate((db) => {
      const h = find(db, id);
      h.hrmsDocumentId = documentId;
      audit(db, h, "system", "document_uploaded", documentId);
    });
  }
  return id;
}

/** Reads one handover through the write queue so it reflects any in-flight change. */
async function mutatePeek(id: string) {
  return mutate((db) => structuredClone(find(db, id)));
}
