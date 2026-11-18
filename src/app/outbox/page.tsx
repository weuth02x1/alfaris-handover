import { ExternalLink, MailOpen } from "lucide-react";
import { AppHeader } from "@/components/app-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { readDb } from "@/lib/db";
import { getI18n } from "@/lib/i18n/server";
import { requireUser } from "@/lib/session";

export default async function OutboxPage() {
  const user = await requireUser("/outbox");
  const { t, date } = await getI18n();
  const db = await readDb();
  const mail = db.outbox.filter((m) => user.role === "hr" || m.toEmployeeId === user.id).reverse();

  return (
    <>
      <AppHeader user={user} />
      <main className="mx-auto w-full max-w-4xl flex-1 space-y-6 px-4 py-8">
        <div>
          <h1 className="text-2xl font-semibold">{t.outbox.title}</h1>
          <p className="text-sm text-muted-foreground">{t.outbox.subtitle}</p>
        </div>
        {mail.length === 0 ? (
          <Card>
            <CardContent className="flex flex-col items-center gap-2 py-14 text-center text-sm text-muted-foreground">
              <MailOpen className="size-8" />
              {t.outbox.empty}
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-3">
            {mail.map((m) => (
              <Card key={m.id} size="sm">
                <CardHeader>
                  <CardTitle className="text-sm leading-relaxed">{m.subject}</CardTitle>
                  <div className="flex flex-wrap gap-x-3 text-xs text-muted-foreground">
                    <span dir="ltr">
                      {t.outbox.to}: {m.to}
                    </span>
                    <span>{date(m.at, true)}</span>
                  </div>
                </CardHeader>
                <CardContent className="space-y-3">
                  <p className="whitespace-pre-line text-sm text-muted-foreground">{m.body}</p>
                  {m.link && (
                    <a
                      href={m.link}
                      className="inline-flex items-center gap-1.5 text-sm font-medium text-primary underline-offset-4 hover:underline"
                    >
                      <ExternalLink className="size-3.5" />
                      {t.outbox.openLink}
                    </a>
                  )}
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </main>
    </>
  );
}
