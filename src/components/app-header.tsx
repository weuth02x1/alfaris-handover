import Link from "next/link";
import { ClipboardCheck, Inbox, LogOut, Mail, ShieldCheck, Languages } from "lucide-react";
import { logout, setLanguage } from "@/app/actions";
import { Button } from "@/components/ui/button";
import { getI18n } from "@/lib/i18n/server";
import type { Employee } from "@/lib/types";

export async function AppHeader({ user }: { user: Employee | null }) {
  const { t, name, locale, pick } = await getI18n();
  return (
    <header className="no-print sticky top-0 z-30 border-b bg-background/85 backdrop-blur">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-4 gap-y-2 px-4 py-3">
        <Link href="/" className="flex items-center gap-2 font-semibold">
          <span className="grid size-8 place-items-center rounded-lg bg-primary text-primary-foreground">
            <ClipboardCheck className="size-4" />
          </span>
          <span>{t.appName}</span>
        </Link>
        <nav className="flex flex-1 flex-wrap items-center gap-1 text-sm">
          {user && (
            <>
              <NavLink href="/" icon={<Inbox className="size-4" />}>{t.nav.inbox}</NavLink>
              {user.role === "hr" && (
                <NavLink href="/hr" icon={<ShieldCheck className="size-4" />}>{t.nav.hr}</NavLink>
              )}
            </>
          )}
          <NavLink href="/outbox" icon={<Mail className="size-4" />}>{t.nav.outbox}</NavLink>
        </nav>
        <div className="flex items-center gap-2">
          <form action={setLanguage}>
            <input type="hidden" name="lang" value={locale === "ar" ? "en" : "ar"} />
            <Button type="submit" variant="ghost" size="sm">
              <Languages className="size-4" />
              {t.nav.language}
            </Button>
          </form>
          {user && (
            <>
              <div className="hidden text-end leading-tight sm:block">
                <div className="text-sm font-medium">{name(user)}</div>
                <div className="text-xs text-muted-foreground">
                  {pick(user.jobTitleAr, user.jobTitleEn)}
                </div>
              </div>
              <form action={logout}>
                <Button type="submit" variant="outline" size="sm" aria-label={t.nav.logout}>
                  <LogOut className="size-4" />
                  <span className="hidden md:inline">{t.nav.logout}</span>
                </Button>
              </form>
            </>
          )}
        </div>
      </div>
    </header>
  );
}

function NavLink({ href, icon, children }: { href: string; icon: React.ReactNode; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="flex items-center gap-1.5 rounded-md px-2.5 py-1.5 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
    >
      {icon}
      {children}
    </Link>
  );
}
