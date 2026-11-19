import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowRight, ShieldCheck } from "lucide-react";
import { BrandLockup } from "@/components/brand-lockup";
import { PrintButton } from "@/components/print-button";
import { buttonVariants } from "@/components/ui/button";
import { dictionaries } from "@/lib/i18n/dict";
import { listPeople } from "@/lib/people";
import { getI18n } from "@/lib/i18n/server";
import { getHandoverFor } from "@/lib/queries";
import { requireUser } from "@/lib/session";

const fmtDate = (iso: string | null, locale: "ar" | "en", withTime = false) => {
  if (!iso) return "—";
  const d = new Date(iso.length === 10 ? `${iso}T00:00:00` : iso);
  return new Intl.DateTimeFormat(locale === "ar" ? "ar-SA-u-ca-gregory-nu-latn" : "en-GB", {
    dateStyle: "medium",
    ...(withTime ? { timeStyle: "short", timeZone: "Asia/Riyadh" } : {}),
  }).format(d);
};

export default async function ReportPage({ params }: PageProps<"/handovers/[id]/report">) {
  const { id } = await params;
  const user = await requireUser(`/handovers/${id}/report`);
  const data = await getHandoverFor(user, id);
  if (!data) notFound();
  const { handover: h, access } = data;
  const { t } = await getI18n();
  if (!(access.isOwner || access.isManager || access.isHr)) notFound();

  const employees = await listPeople();
  const byId = new Map(employees.map((e) => [e.id, e]));
  const both = (id: string | null | undefined) => {
    const e = id ? byId.get(id) : undefined;
    return e ? { ar: e.nameAr, en: e.nameEn } : { ar: "—", en: "—" };
  };

  if (h.status !== "approved") {
    return (
      <main className="mx-auto grid max-w-md flex-1 place-items-center p-10 text-center">
        <div className="space-y-3">
          <p>{t.report.notFinal}</p>
          <Link href={`/handovers/${h.id}`} className={buttonVariants({ variant: "outline" })}>
            {t.report.back}
          </Link>
        </div>
      </main>
    );
  }

  const manager = both(h.managerApproval?.byId);
  const hrUser = both(h.hrApproval?.byId);

  return (
    <main className="mx-auto w-full max-w-4xl flex-1 px-4 py-8 print:max-w-none print:p-0">
      <div className="no-print mb-6 flex items-center justify-between gap-2">
        <Link href={`/handovers/${h.id}`} className={buttonVariants({ variant: "outline" })}>
          <ArrowRight className="size-4 ltr:rotate-180" />
          {t.report.back}
        </Link>
        <PrintButton label={t.report.print} />
      </div>

      <article className="space-y-6 rounded-2xl border bg-white p-8 text-[13px] text-slate-900 shadow-sm print:rounded-none print:border-0 print:p-0 print:shadow-none" dir="rtl">
        <header className="overflow-hidden rounded-xl print:rounded-none">
          <div className="brand-navy flex items-center justify-between gap-4 px-5 py-4 [print-color-adjust:exact]">
            <BrandLockup className="h-12" />
            <p className="text-[11px] tracking-[0.18em] text-[var(--gold)]">ALFARIS GROUP</p>
          </div>
          <div className="flex items-end justify-between gap-4 border-b-2 border-[var(--navy)] px-1 py-4">
          <div>
            <h1 className="text-xl font-bold text-[var(--navy)]">إيصال تسليم المهام</h1>
            <p className="text-slate-500" dir="ltr">Employee Handover Receipt</p>
          </div>
          <div className="text-start text-xs leading-6" dir="ltr">
            <div>
              <span className="text-slate-500">No.</span> <span className="font-mono font-semibold">{h.number}</span>
            </div>
            <div>
              <span className="text-slate-500">Request</span> <span className="font-mono">{h.requestRef}</span>
            </div>
            <div>
              <span className="text-slate-500">Issued</span> {fmtDate(h.finalizedAt, "en", true)}
            </div>
          </div>
          </div>
        </header>

        <section>
          <SectionTitle ar="بيانات الموظف" en="Employee details" />
          <table className="w-full border-collapse">
            <tbody>
              <Row ar="اسم الموظف" en="Employee name" valueAr={h.employee.nameAr} valueEn={h.employee.nameEn} />
              <Row ar="الرقم الوظيفي" en="Employee ID" valueAr={h.employee.id} />
              <Row ar="المسمى الوظيفي" en="Job title" valueAr={h.employee.jobTitleAr} valueEn={h.employee.jobTitleEn} />
              <Row ar="المدير المباشر" en="Direct manager" valueAr={h.employee.managerNameAr || "—"} valueEn={h.employee.managerNameEn} />
              <Row ar="الإدارة" en="Department" valueAr={h.employee.departmentAr} valueEn={h.employee.departmentEn} />
              <Row ar="القسم" en="Section" valueAr={h.employee.sectionAr} valueEn={h.employee.sectionEn} />
              <Row
                ar="سبب الخروج"
                en="Reason for leaving"
                valueAr={dictionaries.ar.type[h.type]}
                valueEn={dictionaries.en.type[h.type]}
              />
              <Row ar="آخر يوم عمل" en="Last working day" valueAr={fmtDate(h.lastWorkingDay, "ar")} />
              {h.returnDate && <Row ar="تاريخ العودة" en="Return date" valueAr={fmtDate(h.returnDate, "ar")} />}
            </tbody>
          </table>
        </section>

        <section>
          <SectionTitle ar="المهام المُسلَّمة" en="Handed-over tasks" />
          <table className="w-full border-collapse text-[12px]">
            <thead>
              <tr className="bg-slate-100">
                <Th ar="#" />
                <Th ar="المهمة" en="Task" />
                <Th ar="المستلم" en="Recipient" />
                <Th ar="الاستحقاق" en="Due" />
                <Th ar="وقت القبول" en="Accepted at" />
              </tr>
            </thead>
            <tbody>
              {h.tasks.map((task, i) => {
                const r = both(task.assigneeId);
                return (
                  <tr key={task.id} className="break-inside-avoid align-top">
                    <td className="border p-2 text-center">{i + 1}</td>
                    <td className="border p-2">
                      <div className="font-semibold">{task.title}</div>
                      {task.details && <div className="mt-1 whitespace-pre-line text-slate-600">{task.details}</div>}
                      {task.acceptNote && <div className="mt-1 text-emerald-800">✓ {task.acceptNote}</div>}
                    </td>
                    <td className="border p-2">
                      <div>{r.ar}</div>
                      <div className="text-slate-500" dir="ltr">{r.en}</div>
                      <div className="font-mono text-[11px] text-slate-500">{task.assigneeId}</div>
                    </td>
                    <td className="border p-2 whitespace-nowrap">{fmtDate(task.dueDate, "ar")}</td>
                    <td className="border p-2 whitespace-nowrap">{fmtDate(task.acceptedAt, "ar", true)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          {h.generalNotes && (
            <div className="mt-3 rounded-lg bg-slate-50 p-3">
              <div className="mb-1 text-xs font-semibold text-slate-500">ملاحظات عامة · General notes</div>
              <p className="whitespace-pre-line">{h.generalNotes}</p>
            </div>
          )}
        </section>

        <section>
          <SectionTitle ar="الاعتمادات" en="Approvals" />
          <div className="grid gap-3 sm:grid-cols-3 print:grid-cols-3">
            <Signature
              roleAr="الموظف (المُسلِّم)"
              roleEn="Employee"
              nameAr={h.employee.nameAr}
              nameEn={h.employee.nameEn}
              at={fmtDate(h.submittedAt, "ar", true)}
            />
            <Signature
              roleAr="المدير المباشر"
              roleEn="Direct manager"
              nameAr={manager.ar}
              nameEn={manager.en}
              at={fmtDate(h.managerApproval?.at ?? null, "ar", true)}
              note={h.managerApproval?.comment}
            />
            <Signature
              roleAr="الموارد البشرية"
              roleEn="Human Resources"
              nameAr={hrUser.ar}
              nameEn={hrUser.en}
              at={fmtDate(h.hrApproval?.at ?? null, "ar", true)}
              note={h.hrApproval?.comment}
            />
          </div>
        </section>

        <footer className="space-y-2 border-t pt-4 text-[11px] text-slate-500">
          <p className="flex items-start gap-1.5">
            <ShieldCheck className="mt-0.5 size-3.5 shrink-0 text-primary" />
            هذا المستند صادر آلياً من نظام تسليم المهام ومقفل بعد الاعتماد النهائي، ومحفوظ في ملف الموظف بنظام الموارد البشرية.
          </p>
          <p dir="ltr">
            This document was generated by the handover system, locked after final approval, and filed on the employee
            record in the HR system.
          </p>
          <div dir="ltr" className="flex flex-wrap gap-x-6 font-mono">
            <span>SHA-256: {h.documentHash}</span>
            {h.hrmsDocumentId && <span>HRMS doc: {h.hrmsDocumentId}</span>}
          </div>
        </footer>
      </article>
    </main>
  );
}

function SectionTitle({ ar, en }: { ar: string; en: string }) {
  return (
    <h2 className="mb-2 flex items-baseline justify-between border-b pb-1 font-bold text-primary">
      <span>{ar}</span>
      <span className="text-xs font-medium text-slate-500" dir="ltr">
        {en}
      </span>
    </h2>
  );
}

function Row({ ar, en, valueAr, valueEn }: { ar: string; en: string; valueAr: string; valueEn?: string }) {
  return (
    <tr>
      <th className="w-1/4 border bg-slate-50 p-2 text-start font-medium">{ar}</th>
      <td className="border p-2">{valueAr}</td>
      <td className="border p-2 text-slate-600" dir="ltr">
        {valueEn ?? ""}
      </td>
      <th className="w-1/4 border bg-slate-50 p-2 text-end font-medium" dir="ltr">
        {en}
      </th>
    </tr>
  );
}

function Th({ ar, en }: { ar: string; en?: string }) {
  return (
    <th className="border p-2 text-start font-semibold">
      <div>{ar}</div>
      {en && <div className="text-[10px] font-normal text-slate-500">{en}</div>}
    </th>
  );
}

function Signature({
  roleAr,
  roleEn,
  nameAr,
  nameEn,
  at,
  note,
}: {
  roleAr: string;
  roleEn: string;
  nameAr: string;
  nameEn: string;
  at: string;
  note?: string | null;
}) {
  return (
    <div className="break-inside-avoid rounded-lg border p-3">
      <div className="text-xs text-slate-500">
        {roleAr} · <span dir="ltr">{roleEn}</span>
      </div>
      <div className="mt-1 font-semibold">{nameAr}</div>
      <div className="text-slate-500" dir="ltr">
        {nameEn}
      </div>
      <div className="mt-2 text-[11px] text-emerald-700">✓ {at}</div>
      {note && <div className="mt-1 text-[11px] text-slate-600">{note}</div>}
    </div>
  );
}
