import Link from "next/link";
import { redirect } from "next/navigation";
import { Database, FileCheck2 } from "lucide-react";
import { AppHeader } from "@/components/app-header";
import { StartClearanceButton } from "@/components/start-clearance-button";
import { HandoverStatusBadge } from "@/components/status-badge";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { readDb } from "@/lib/db";
import { hr } from "@/lib/hr";
import { mockApprovedRequests } from "@/lib/hr/mock-data";
import { listPeople } from "@/lib/people";
import { fmt } from "@/lib/i18n/dict";
import { EXIT_REASONS } from "@/lib/types";
import { getI18n } from "@/lib/i18n/server";
import { requireUser } from "@/lib/session";

export default async function HrPage() {
  const user = await requireUser("/hr");
  if (user.role !== "hr") redirect("/");
  const { t, name, date } = await getI18n();
  const provider = hr();
  let requests = mockApprovedRequests;
  let sourceName = "mock";
  if (provider.name === "menaitech") {
    try {
      requests = await provider.listApprovedRequests();
      sourceName = provider.name;
    } catch {
      requests = mockApprovedRequests;
    }
  }
  const [employees, db] = await Promise.all([listPeople(), readDb()]);
  const byId = new Map(employees.map((e) => [e.id, e]));
  const started = new Set(db.handovers.map((h) => h.requestRef));
  const handovers = [...db.handovers].sort((a, b) => b.createdAt.localeCompare(a.createdAt));

  return (
    <>
      <AppHeader user={user} />
      <main className="mx-auto w-full max-w-6xl flex-1 space-y-6 px-4 py-8">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <h1 className="text-2xl font-semibold">{t.hr.title}</h1>
            <p className="text-sm text-muted-foreground">{t.hr.subtitle}</p>
          </div>
          <Badge variant="outline" className="gap-1.5">
            <Database className="size-3.5" />
            {t.hr.source}: {sourceName === "mock" ? t.hr.sourceMock : t.hr.sourceLive}
          </Badge>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>{t.hr.approvedRequests}</CardTitle>
            <CardDescription>{t.hr.approvedRequestsHint}</CardDescription>
          </CardHeader>
          <CardContent className="overflow-x-auto">
            {requests.length === 0 ? (
              <p className="py-6 text-center text-sm text-muted-foreground">{t.hr.noRequests}</p>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-start">{t.hr.ref}</TableHead>
                    <TableHead className="text-start">{t.hr.employee}</TableHead>
                    <TableHead className="text-start">{t.hr.type}</TableHead>
                    <TableHead className="text-start">{t.hr.from}</TableHead>
                    <TableHead className="text-start">{t.hr.to}</TableHead>
                    <TableHead />
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {requests.map((r) => (
                    <TableRow key={r.ref}>
                      <TableCell className="font-mono text-xs">{r.ref}</TableCell>
                      <TableCell>{name(byId.get(r.employeeId))}</TableCell>
                      <TableCell>{t.type[r.type]}</TableCell>
                      <TableCell>{date(r.startDate)}</TableCell>
                      <TableCell>{date(r.endDate)}</TableCell>
                      <TableCell className="text-end">
                        {started.has(r.ref) ? (
                          <Badge variant="secondary">{t.hr.alreadyStarted}</Badge>
                        ) : (
                          <StartClearanceButton
                            requestRef={r.ref}
                            defaultReason={r.type}
                            reasons={EXIT_REASONS.map((reason) => ({ value: reason, label: t.type[reason] }))}
                            label={t.hr.startClearance}
                            errorLabel={t.errors.notAllowed}
                            doneLabel={t.audit.link_sent}
                          />
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <FileCheck2 className="size-4" />
              {t.hr.allHandovers}
            </CardTitle>
          </CardHeader>
          <CardContent className="overflow-x-auto">
            {handovers.length === 0 ? (
              <p className="py-6 text-center text-sm text-muted-foreground">{t.hr.noHandovers}</p>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="text-start">{t.hr.number}</TableHead>
                    <TableHead className="text-start">{t.hr.employee}</TableHead>
                    <TableHead className="text-start">{t.hr.type}</TableHead>
                    <TableHead className="text-start">{t.hr.progress}</TableHead>
                    <TableHead className="text-start">{t.hr.status}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {handovers.map((h) => (
                    <TableRow key={h.id}>
                      <TableCell>
                        <Link href={`/handovers/${h.id}`} className="font-mono text-xs text-primary underline-offset-4 hover:underline">
                          {h.number}
                        </Link>
                      </TableCell>
                      <TableCell>{name(h.employee)}</TableCell>
                      <TableCell>{t.type[h.type]}</TableCell>
                      <TableCell className="text-xs text-muted-foreground">
                        {h.tasks.length === 0
                          ? t.common.dash
                          : fmt(t.form.progress, {
                              a: h.tasks.filter((x) => x.status === "accepted").length,
                              b: h.tasks.length,
                            })}
                      </TableCell>
                      <TableCell>
                        <HandoverStatusBadge status={h.status} label={t.status[h.status]} />
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>
      </main>
    </>
  );
}
