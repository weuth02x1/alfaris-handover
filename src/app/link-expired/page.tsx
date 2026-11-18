import Link from "next/link";
import { LinkIcon } from "lucide-react";
import { AppHeader } from "@/components/app-header";
import { buttonVariants } from "@/components/ui/button";
import { getI18n } from "@/lib/i18n/server";
import { currentUser } from "@/lib/session";

export default async function LinkExpired() {
  const { t } = await getI18n();
  const user = await currentUser();
  return (
    <>
      <AppHeader user={user} />
      <main className="mx-auto grid w-full max-w-md flex-1 place-items-center px-4 py-16 text-center">
        <div className="space-y-3">
          <div className="mx-auto grid size-12 place-items-center rounded-full bg-rose-50 text-rose-600">
            <LinkIcon className="size-5" />
          </div>
          <h1 className="text-lg font-semibold">{t.errors.invalidLink}</h1>
          <p className="text-sm text-muted-foreground">{t.errors.invalidLinkHint}</p>
          <Link href="/" className={buttonVariants()}>{t.nav.inbox}</Link>
        </div>
      </main>
    </>
  );
}
