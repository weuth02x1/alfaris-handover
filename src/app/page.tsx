import Link from "next/link";
import { ArrowUpRight, CheckCircle2, ClipboardList, Hand, Inbox, ShieldCheck, UserCheck } from "lucide-react";
import { AppHeader } from "@/components/app-header";
import { HandoverStatusBadge, TaskStatusBadge } from "@/components/status-badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { getI18n } from "@/lib/i18n/server";
import { inboxFor } from "@/lib/queries";
import { requireUser } from "@/lib/session";
import type { Handover } from "@/lib/types";

export default async function InboxPage() {
  const user = await requireUser("/");
  const { t, pick, date } = await getI18n();
  const { mine, toAccept, accepted, managerQueue, hrQueue } = await inboxFor(user);
  const empty =
    mine.length + toAccept.length + accepted.length + managerQueue.length + hrQueue.length === 0;

  const empName = (h: Handover) => pick(h.employee.nameAr, h.employee.nameEn);

  return (
    <>
      <AppHeader user={user} />
      <main className="mx-auto w-full max-w-6xl flex-1 space-y-6 px-4 py-8">
        <div>
          <h1 className="text-2xl font-semibold">{t.inbox.title}</h1>
          <p className="text-sm text-muted-foreground">{t.inbox.subtitle}</p>
        </div>

        {empty && (
          <Card>
            <CardContent className="flex flex-col items-center gap-2 py-14 text-center">
              <Inbox className="size-8 text-muted-foreground" />
              <p className="font-medium">{t.inbox.nothing}</p>
              <p className="max-w-sm text-sm text-muted-foreground">{t.inbox.nothingHint}</p>
            </CardContent>
          </Card>
        )}

        <div className="grid gap-6 lg:grid-cols-2">
          {toAccept.length > 0 && (
            <Section icon={<Hand className="size-4" />} title={t.inbox.tasksToAccept} highlight>
              {toAccept.map(({ h, t: task }) => (
                <Row
                  key={task.id}
                  href={`/handovers/${h.id}#task-${task.id}`}
                  title={task.title}
                  meta={`${t.inbox.from} ${empName(h)} · ${h.number}`}
                  badge={<TaskStatusBadge status={task.status} label={t.taskStatus[task.status]} />}
                />
              ))}
            </Section>
          )}

          {mine.length > 0 && (
            <Section icon={<ClipboardList className="size-4" />} title={t.inbox.myHandovers} highlight>
              {mine.map((h) => (
                <Row
                  key={h.id}
                  href={`/handovers/${h.id}`}
                  title={`${h.number} · ${t.type[h.type]}`}
                  meta={`${h.requestRef} · ${date(h.lastWorkingDay)}`}
                  badge={<HandoverStatusBadge status={h.status} label={t.status[h.status]} />}
                />
              ))}
            </Section>
          )}

          {managerQueue.length > 0 && (
            <Section icon={<UserCheck className="size-4" />} title={t.inbox.managerQueue} highlight>
              {managerQueue.map((h) => (
                <Row
                  key={h.id}
                  href={`/handovers/${h.id}`}
                  title={empName(h)}
                  meta={`${h.number} · ${t.type[h.type]}`}
                  badge={<HandoverStatusBadge status={h.status} label={t.status[h.status]} />}
                />
              ))}
            </Section>
          )}

          {hrQueue.length > 0 && (
            <Section icon={<ShieldCheck className="size-4" />} title={t.inbox.hrQueue} highlight>
              {hrQueue.map((h) => (
                <Row
                  key={h.id}
                  href={`/handovers/${h.id}`}
                  title={empName(h)}
                  meta={`${h.number} · ${t.type[h.type]}`}
                  badge={<HandoverStatusBadge status={h.status} label={t.status[h.status]} />}
                />
              ))}
            </Section>
          )}

          {accepted.length > 0 && (
            <Section icon={<CheckCircle2 className="size-4" />} title={t.inbox.acceptedByMe}>
              {accepted.map(({ h, t: task }) => (
                <Row
                  key={task.id}
                  href={`/handovers/${h.id}#task-${task.id}`}
                  title={task.title}
                  meta={`${t.inbox.from} ${empName(h)} · ${date(task.acceptedAt)}`}
                  badge={<TaskStatusBadge status={task.status} label={t.taskStatus[task.status]} />}
                />
              ))}
            </Section>
          )}
        </div>
      </main>
    </>
  );
}

function Section({
  icon,
  title,
  children,
  highlight,
}: {
  icon: React.ReactNode;
  title: string;
  children: React.ReactNode;
  highlight?: boolean;
}) {
  return (
    <Card className={highlight ? "border-primary/30" : undefined}>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-base">
          <span className="grid size-7 place-items-center rounded-md bg-primary/10 text-primary">{icon}</span>
          {title}
        </CardTitle>
      </CardHeader>
      <CardContent className="divide-y p-0">{children}</CardContent>
    </Card>
  );
}

function Row({ href, title, meta, badge }: { href: string; title: string; meta: string; badge: React.ReactNode }) {
  return (
    <Link href={href} className="group flex items-center gap-3 px-4 py-3 transition hover:bg-muted/60">
      <div className="min-w-0 flex-1">
        <div className="truncate font-medium">{title}</div>
        <div className="truncate text-xs text-muted-foreground">{meta}</div>
      </div>
      {badge}
      <ArrowUpRight className="size-4 shrink-0 text-muted-foreground transition group-hover:text-foreground rtl:-scale-x-100" />
    </Link>
  );
}
