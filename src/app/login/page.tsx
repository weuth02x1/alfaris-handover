import { redirect } from "next/navigation";
import { UserRound } from "lucide-react";
import { loginAs, setLanguage } from "@/app/actions";
import { BrandLockup } from "@/components/brand-lockup";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { hr } from "@/lib/hr";
import { getI18n } from "@/lib/i18n/server";
import { currentUser, demoLoginEnabled } from "@/lib/session";
import { cn } from "@/lib/utils";

export default async function LoginPage({ searchParams }: PageProps<"/login">) {
  const sp = await searchParams;
  const next = typeof sp.next === "string" ? sp.next : "/";
  const forId = typeof sp.for === "string" ? sp.for : null;
  const user = await currentUser();
  if (user && (!forId || forId === user.id)) redirect(next);

  const { t, name, pick, locale } = await getI18n();
  const employees = await hr().listEmployees();
  const intended = forId ? employees.find((e) => e.id === forId) : null;
  const list = intended ? [intended, ...employees.filter((e) => e.id !== intended.id)] : employees;

  return (
    <main className="grid min-h-full flex-1 lg:grid-cols-2">
      <section className="brand-navy relative flex min-h-56 flex-col justify-between overflow-hidden px-8 py-10 lg:min-h-full lg:px-12">
        <div className="brand-mark-watermark pointer-events-none absolute -bottom-16 -inset-inline-start-16 size-80" />
        <div className="brand-mark-watermark pointer-events-none absolute -top-24 -inset-inline-end-24 size-72 rotate-12" />
        <BrandLockup className="relative h-14 w-auto max-w-full object-contain sm:h-20" />
        <div className="relative max-w-md space-y-4">
          <div className="h-px w-16 bg-[var(--gold)]" />
          <h1 className="text-3xl font-semibold leading-snug text-[var(--cream)] sm:text-4xl">{t.appName}</h1>
          <p className="text-sm leading-relaxed text-[var(--gold)]">{t.appTagline}</p>
        </div>
        <p className="relative text-xs tracking-[0.22em] text-[var(--gold)]/80">ALFARIS GROUP</p>
      </section>
      <section className="flex flex-col px-5 py-8 sm:px-10">
        <div className="mb-6 flex justify-end">
          <form action={setLanguage}>
            <input type="hidden" name="lang" value={locale === "ar" ? "en" : "ar"} />
            <Button type="submit" variant="ghost" size="sm">{t.nav.language}</Button>
          </form>
        </div>
        <div className="mx-auto w-full max-w-xl flex-1 space-y-4">
          <div>
            <h2 className="text-xl font-semibold">{t.login.title}</h2>
            <p className="mt-1 text-sm text-muted-foreground">{t.login.subtitle}</p>
          </div>
            {intended && (
              <Alert>
                <AlertDescription>
                  {t.login.linkFor} <strong>{name(intended)}</strong> ({intended.id})
                </AlertDescription>
              </Alert>
            )}
            {demoLoginEnabled() ? (
              <>
                <p className="text-sm text-muted-foreground">{t.login.demoNote}</p>
                <div className="grid gap-2 sm:grid-cols-2">
                  {list.map((e) => (
                    <form key={e.id} action={loginAs}>
                      <input type="hidden" name="employeeId" value={e.id} />
                      <input type="hidden" name="next" value={next} />
                      <button
                        type="submit"
                        className={cn(
                          "flex w-full items-center gap-3 rounded-xl border bg-card p-3 text-start transition hover:border-primary hover:bg-primary/5",
                          intended?.id === e.id && "border-primary ring-2 ring-primary/20",
                        )}
                      >
                        <span className="grid size-9 shrink-0 place-items-center rounded-full bg-muted">
                          <UserRound className="size-4 text-muted-foreground" />
                        </span>
                        <span className="min-w-0 flex-1">
                          <span className="flex items-center gap-2 font-medium">
                            {name(e)}
                            {e.role === "hr" && <Badge variant="secondary">{t.login.hrBadge}</Badge>}
                          </span>
                          <span className="block truncate text-xs text-muted-foreground">
                            {pick(e.jobTitleAr, e.jobTitleEn)} · {pick(e.departmentAr, e.departmentEn)}
                          </span>
                        </span>
                      </button>
                    </form>
                  ))}
                </div>
              </>
            ) : (
              <p className="text-sm text-muted-foreground">{t.login.subtitle}</p>
            )}
        </div>
      </section>
    </main>
  );
}
