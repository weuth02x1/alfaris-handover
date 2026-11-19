"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Loader2 } from "lucide-react";
import { requestOtpAction, verifyOtpAction } from "@/app/actions";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { Dict } from "@/lib/i18n/dict";

export function LoginForm({ t, next, initialId }: { t: Dict; next: string; initialId?: string }) {
  const router = useRouter();
  const [identifier, setIdentifier] = useState(initialId ?? "");
  const [code, setCode] = useState("");
  const [masked, setMasked] = useState<string | null>(null);
  const [devCode, setDevCode] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();

  const send = () => {
    setError(null);
    start(async () => {
      const result = await requestOtpAction(identifier);
      if (!result.ok) {
        setError(t.login[result.error]);
        return;
      }
      setMasked(result.maskedEmail);
      setDevCode(result.devCode ?? null);
    });
  };

  const confirm = () => {
    setError(null);
    start(async () => {
      const result = await verifyOtpAction(identifier, code, next);
      if (!result.ok) {
        setError(t.login[result.error]);
        return;
      }
      router.push(result.next);
      router.refresh();
    });
  };

  return (
    <div className="space-y-4">
      <div className="space-y-1.5">
        <Label htmlFor="employee-no">{t.login.employeeNo}</Label>
        <Input
          id="employee-no"
          inputMode="numeric"
          autoComplete="username"
          value={identifier}
          placeholder={t.login.employeeNoPh}
          onChange={(event) => setIdentifier(event.target.value)}
        />
      </div>
      {masked && (
        <div className="space-y-3">
          <p className="text-sm text-muted-foreground">
            {t.login.codeSent} <span dir="ltr">{masked}</span>
          </p>
          {devCode && (
            <Alert>
              <AlertDescription>
                {t.login.devCode}
                <span className="mt-2 block font-mono text-2xl tracking-[0.3em] text-foreground" dir="ltr">
                  {devCode}
                </span>
              </AlertDescription>
            </Alert>
          )}
          <div className="space-y-1.5">
            <Label htmlFor="otp">{t.login.code}</Label>
            <Input
              id="otp"
              inputMode="numeric"
              autoComplete="one-time-code"
              maxLength={6}
              value={code}
              onChange={(event) => setCode(event.target.value)}
              dir="ltr"
              className="text-center font-mono text-lg tracking-[0.4em]"
            />
          </div>
        </div>
      )}
      {error && <p className="text-sm text-destructive">{error}</p>}
      <div className="flex flex-wrap gap-2">
        {masked ? (
          <>
            <Button type="button" disabled={pending || code.trim().length < 6} onClick={confirm}>
              {pending && <Loader2 className="size-4 animate-spin" />}
              {t.login.confirm}
            </Button>
            <Button type="button" variant="outline" disabled={pending} onClick={send}>
              {t.login.resend}
            </Button>
          </>
        ) : (
          <Button type="button" disabled={pending || !identifier.trim()} onClick={send}>
            {pending && <Loader2 className="size-4 animate-spin" />}
            {t.login.sendCode}
          </Button>
        )}
      </div>
    </div>
  );
}
