import { redirect } from "next/navigation";
import { KeyRound, UserRound } from "lucide-react";
import { loginAs } from "@/app/actions";
import { AppHeader } from "@/components/app-header";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
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

  const { t, name, pick } = await getI18n();
  const employees = await hr().listEmployees();
  const intended = forId ? employees.find((e) => e.id === forId) : null;
  const list = intended ? [intended, ...employees.filter((e) => e.id !== intended.id)] : employees;

  return (
    <>
      <AppHeader user={null} />
      <main className="mx-auto w-full max-w-3xl flex-1 px-4 py-10">
        <Card>
          <CardHeader>
            <div className="mb-2 grid size-10 place-items-center rounded-xl bg-primary/10 text-primary">
              <KeyRound className="size-5" />
            </div>
            <CardTitle className="text-xl">{t.login.title}</CardTitle>
            <CardDescription>{t.login.subtitle}</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
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
          </CardContent>
        </Card>
      </main>
    </>
  );
}
