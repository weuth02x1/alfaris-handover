import "server-only";
import { cookies } from "next/headers";
import { dictionaries, type Locale } from "./dict";
import type { Employee, EmployeeSnapshot } from "@/lib/types";

export async function getLocale(): Promise<Locale> {
  return (await cookies()).get("lang")?.value === "en" ? "en" : "ar";
}

export async function getI18n() {
  const locale = await getLocale();
  const t = dictionaries[locale];
  const name = (e: Pick<Employee, "nameAr" | "nameEn"> | null | undefined) =>
    e ? (locale === "ar" ? e.nameAr : e.nameEn) : t.common.dash;
  const pick = (arVal: string, enVal: string) => (locale === "ar" ? arVal : enVal);
  const date = (iso: string | null | undefined, withTime = false) => {
    if (!iso) return t.common.dash;
    const d = new Date(iso.length === 10 ? `${iso}T00:00:00` : iso);
    return new Intl.DateTimeFormat(locale === "ar" ? "ar-SA-u-ca-gregory-nu-latn" : "en-GB", {
      dateStyle: "medium",
      ...(withTime ? { timeStyle: "short", timeZone: "Asia/Riyadh" } : {}),
    }).format(d);
  };
  const snapshotJob = (s: EmployeeSnapshot) => pick(s.jobTitleAr, s.jobTitleEn);
  return { locale, t, name, pick, date, snapshotJob, dir: locale === "ar" ? "rtl" : "ltr" };
}
