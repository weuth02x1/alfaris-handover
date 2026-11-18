import Link from "next/link";
import { notFound } from "next/navigation";
import { AlertTriangle, CalendarDays, FileText, History, Lock, UserRound } from "lucide-react";
import { AppHeader } from "@/components/app-header";
import { DecisionPanel } from "@/components/handover/decision-panel";
import { HandoverEditor } from "@/components/handover/handover-editor";
import { StepTracker } from "@/components/handover/step-tracker";
import { ReassignControl, RecipientActions } from "@/components/handover/task-actions";
import type { PersonOption } from "@/components/handover/assignee-select";
import { HandoverStatusBadge, TaskStatusBadge } from "@/components/status-badge";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { buttonVariants } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { hr } from "@/lib/hr";
import { fmt } from "@/lib/i18n/dict";
import { getI18n } from "@/lib/i18n/server";
import { getHandoverFor } from "@/lib/queries";
import { requireUser } from "@/lib/session";

export default async function HandoverPage({ params }: PageProps<"/handovers/[id]">) {
  const { id } = await params;
  const user = await requireUser(`/handovers/${id}`);
  const data = await getHandoverFor(user, id);
  if (!data) notFound();
  const { handover: h, access, audit } = data;
  const { t, name, pick, date } = await getI18n();

  const employees = await hr().listEmployees();
  const byId = new Map(employees.map((e) => [e.id, e]));
  const editable = access.isOwner && (h.status === "draft" || h.status === "returned");
  const colleagues: PersonOption[] = access.isOwner
    ? (await hr().listColleagues(user.id)).map((c) => ({
        id: c.id,
        label: name(c),
        sub: `${pick(c.jobTitleAr, c.jobTitleEn)} · ${pick(c.sectionAr, c.sectionEn)}`,
      }))
    : [];
  const rejectedTasks = h.tasks.filter((x) => x.status === "rejected");
  const acceptedCount = h.tasks.filter((x) => x.status === "accepted").length;
  const visibleTasks =
    access.isOwner || access.isManager || access.isHr
      ? h.tasks
      : h.tasks.filter((x) => x.assigneeId === user.id || x.rejections.some((r) => r.recipientId === user.id));

  return (
    <>
      <AppHeader user={user} />
      <main className="mx-auto w-full max-w-5xl flex-1 space-y-6 px-4 py-8">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="space-y-1">
            <div className="flex flex-wrap items-center gap-2">
              <h1 className="font-mono text-2xl font-semibold">{h.number}</h1>
              <HandoverStatusBadge status={h.status} label={t.status[h.status]} />
            </div>
            <p className="text-sm text-muted-foreground">
              {name(h.employee)} · {t.type[h.type]} · {h.requestRef}
            </p>
          </div>
          {h.status === "approved" && (
            <Link href={`/handovers/${h.id}/report`} className={buttonVariants()}>
              <FileText className="size-4" />
              {t.form.viewReport}
            </Link>
          )}
        </div>

        <Card>
          <CardContent>
            <StepTracker
              status={h.status}
              labels={[
                t.status.draft,
                t.status.pending_acceptance,
                t.status.pending_manager,
                t.status.pending_hr,
                t.status.approved,
              ]}
            />
          </CardContent>
        </Card>

        {h.status === "returned" && h.lastReturn && (
          <Alert variant="destructive">
            <AlertTriangle className="size-4" />
            <AlertTitle>
              {t.form.returnedBanner} {t.form.returnedBy} {name(byId.get(h.lastReturn.byId))}
            </AlertTitle>
            <AlertDescription>{h.lastReturn.comment}</AlertDescription>
          </Alert>
        )}

        {access.isOwner && rejectedTasks.length > 0 && h.status === "pending_acceptance" && (
          <Alert variant="destructive">
            <AlertTriangle className="size-4" />
            <AlertTitle>{t.form.rejectedTasksBanner}</AlertTitle>
          </Alert>
        )}

        <div className="grid gap-6 md:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base">
                <UserRound className="size-4" />
                {t.form.employeeInfo}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <dl className="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
                <Field label={t.form.name} value={name(h.employee)} />
                <Field label={t.form.id} value={h.employee.id} mono />
                <Field label={t.form.jobTitle} value={pick(h.employee.jobTitleAr, h.employee.jobTitleEn)} />
                <Field
                  label={t.form.manager}
                  value={pick(h.employee.managerNameAr, h.employee.managerNameEn) || t.common.dash}
                />
                <Field label={t.form.department} value={pick(h.employee.departmentAr, h.employee.departmentEn)} />
                <Field label={t.form.section} value={pick(h.employee.sectionAr, h.employee.sectionEn)} />
              </dl>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base">
                <CalendarDays className="size-4" />
                {t.form.clearanceInfo}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <dl className="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
                <Field label={t.form.requestRef} value={h.requestRef} mono />
                <Field label={t.form.type} value={t.type[h.type]} />
                <Field label={t.form.lastWorkingDay} value={date(h.lastWorkingDay)} />
                <Field label={t.form.returnDate} value={date(h.returnDate)} />
                <Field
                  label={t.hr.progress}
                  value={h.tasks.length ? fmt(t.form.progress, { a: acceptedCount, b: h.tasks.length }) : t.common.dash}
                />
              </dl>
            </CardContent>
          </Card>
        </div>

        {editable ? (
          <HandoverEditor
            handoverId={h.id}
            t={t}
            colleagues={colleagues}
            initialNotes={h.generalNotes}
            initialTasks={h.tasks.map((x) => ({
              id: x.id,
              title: x.title,
              details: x.details,
              dueDate: x.dueDate ?? "",
              assigneeId: x.assigneeId,
            }))}
          />
        ) : (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                {t.form.tasks}
                {h.status === "approved" && <Lock className="size-4 text-muted-foreground" />}
              </CardTitle>
              {!access.isRecipient && <p className="text-xs text-muted-foreground">{t.form.readOnly}</p>}
            </CardHeader>
            <CardContent className="space-y-3">
              {visibleTasks.map((task) => {
                const mineToAct =
                  task.assigneeId === user.id && task.status === "pending" && h.status === "pending_acceptance";
                return (
                  <div
                    key={task.id}
                    id={`task-${task.id}`}
                    className={`scroll-mt-24 space-y-3 rounded-xl border p-4 ${mineToAct ? "border-primary/50" : ""}`}
                  >
                    <div className="flex flex-wrap items-start justify-between gap-2">
                      <div className="space-y-1">
                        <div className="flex flex-wrap items-center gap-2 font-medium">
                          {task.title}
                          {task.assigneeId === user.id && <Badge variant="secondary">{t.form.yourTask}</Badge>}
                        </div>
                        <div className="text-xs text-muted-foreground">
                          {t.form.assignee}: {name(byId.get(task.assigneeId))}
                          {task.dueDate && ` · ${t.form.dueDate}: ${date(task.dueDate)}`}
                          {task.acceptedAt && ` · ${t.form.acceptedAt}: ${date(task.acceptedAt, true)}`}
                        </div>
                      </div>
                      <TaskStatusBadge status={task.status} label={t.taskStatus[task.status]} />
                    </div>
                    {task.details && <p className="whitespace-pre-line text-sm">{task.details}</p>}
                    {task.acceptNote && (
                      <p className="rounded-md bg-emerald-50 px-3 py-2 text-xs text-emerald-900">{task.acceptNote}</p>
                    )}
                    {task.rejections.length > 0 && (access.isOwner || access.isManager || access.isHr) && (
                      <ul className="space-y-1">
                        {task.rejections.map((r) => (
                          <li key={r.at} className="rounded-md bg-rose-50 px-3 py-2 text-xs text-rose-900">
                            {t.form.previouslyRejectedBy} <strong>{name(byId.get(r.recipientId))}</strong> ·{" "}
                            {date(r.at, true)} — {r.comment}
                          </li>
                        ))}
                      </ul>
                    )}
                    {mineToAct && <RecipientActions handoverId={h.id} taskId={task.id} taskTitle={task.title} t={t} />}
                    {access.isOwner && task.status === "rejected" && h.status === "pending_acceptance" && (
                      <ReassignControl
                        handoverId={h.id}
                        taskId={task.id}
                        options={colleagues}
                        excludedIds={task.rejections.map((r) => r.recipientId)}
                        t={t}
                      />
                    )}
                  </div>
                );
              })}
              {h.generalNotes && (access.isOwner || access.isManager || access.isHr) && (
                <div className="rounded-xl bg-muted/50 p-4">
                  <div className="mb-1 text-xs font-semibold text-muted-foreground">{t.form.generalNotes}</div>
                  <p className="whitespace-pre-line text-sm">{h.generalNotes}</p>
                </div>
              )}
            </CardContent>
          </Card>
        )}

        {h.status === "pending_manager" && access.isManager && <DecisionPanel handoverId={h.id} kind="manager" t={t} />}
        {h.status === "pending_hr" && access.isHr && <DecisionPanel handoverId={h.id} kind="hr" t={t} />}

        {(access.isOwner || access.isManager || access.isHr) && (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base">
                <History className="size-4" />
                {t.form.auditTrail}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <ol className="relative space-y-4 border-s ps-5">
                {audit.map((a) => (
                  <li key={a.id} className="relative">
                    <span className="absolute -start-[25px] top-1.5 size-2.5 rounded-full bg-primary" />
                    <div className="flex flex-wrap items-baseline gap-x-2 text-sm">
                      <span className="font-medium">{t.audit[a.action]}</span>
                      <span className="text-xs text-muted-foreground">
                        {a.actorId === "system" ? "System" : name(byId.get(a.actorId))} · {date(a.at, true)}
                      </span>
                    </div>
                    {a.details && <p className="text-xs text-muted-foreground">{a.details}</p>}
                  </li>
                ))}
              </ol>
            </CardContent>
          </Card>
        )}
      </main>
    </>
  );
}

function Field({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div>
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className={mono ? "font-mono" : "font-medium"}>{value}</dd>
    </div>
  );
}
