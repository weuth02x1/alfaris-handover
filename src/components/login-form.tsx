"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Loader2 } from "lucide-react";
import { registerAction, requestOtpAction, verifyOtpAction } from "@/app/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { Dict } from "@/lib/i18n/dict";

type Mode = "signin" | "signup";

export function LoginForm({ t, next, initialEmail }: { t: Dict; next: string; initialEmail?: string }) {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>("signin");
  const [email, setEmail] = useState(initialEmail ?? "");
  const [name, setName] = useState("");
  const [employeeNo, setEmployeeNo] = useState("");
  const [jobTitle, setJobTitle] = useState("");
  const [departmentId, setDepartmentId] = useState("D-HR");
  const [code, setCode] = useState("");
  const [codeStep, setCodeStep] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();

  const departments = [
    { id: "D-HR", label: t.login.deptHr },
    { id: "D-TA", label: t.login.deptTalent },
    { id: "D-ITD", label: t.login.deptIt },
  ];

  const sent = (result: { ok: true } | { ok: false; error: string }) => {
    if (!result.ok) {
      const key = result.error as keyof typeof t.login;
      setError(typeof t.login[key] === "string" ? (t.login[key] as string) : t.login.invalid);
      return;
    }
    setCodeStep(true);
  };

  const send = () => {
    setError(null);
    start(async () => {
      sent(await requestOtpAction(email));
    });
  };

  const create = () => {
    setError(null);
    start(async () => {
      sent(
        await registerAction({
          email,
          name,
          employeeNo,
          jobTitle,
          departmentId,
        }),
      );
    });
  };

  const confirm = () => {
    setError(null);
    start(async () => {
      const result = await verifyOtpAction(email, code, next);
      if (!result.ok) {
        const key = result.error;
        setError(t.login[key]);
        return;
      }
      router.push(result.next);
      router.refresh();
    });
  };

  return (
    <div className="space-y-4">
      <div className="space-y-1.5">
        <Label htmlFor="email">{t.login.email}</Label>
        <Input
          id="email"
          type="email"
          autoComplete="email"
          dir="ltr"
          value={email}
          placeholder={t.login.emailPh}
          onChange={(event) => setEmail(event.target.value)}
        />
      </div>

      {mode === "signup" && !codeStep && (
        <div className="space-y-3 rounded-xl border bg-card p-4">
          <div>
            <h3 className="font-medium">{t.login.signupTitle}</h3>
            <p className="mt-1 text-sm text-muted-foreground">{t.login.signupHint}</p>
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="name">{t.login.name}</Label>
            <Input id="name" value={name} placeholder={t.login.namePh} onChange={(event) => setName(event.target.value)} />
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor="employee-no">{t.login.employeeNo}</Label>
              <Input
                id="employee-no"
                inputMode="numeric"
                value={employeeNo}
                placeholder={t.login.employeeNoPh}
                onChange={(event) => setEmployeeNo(event.target.value)}
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="job">{t.login.jobTitle}</Label>
              <Input id="job" value={jobTitle} placeholder={t.login.jobTitlePh} onChange={(event) => setJobTitle(event.target.value)} />
            </div>
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="dept">{t.login.department}</Label>
            <select
              id="dept"
              value={departmentId}
              onChange={(event) => setDepartmentId(event.target.value)}
              className="h-9 w-full rounded-lg border bg-card px-3 text-sm"
            >
              {departments.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.label}
                </option>
              ))}
            </select>
          </div>
        </div>
      )}

      {codeStep && (
        <div className="space-y-3">
          <p className="text-sm text-muted-foreground">{t.login.codeSent}</p>
          <p className="text-sm">{t.login.checkInbox}</p>
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
        {codeStep ? (
          <>
            <Button type="button" disabled={pending || code.trim().length < 6} onClick={confirm}>
              {pending && <Loader2 className="size-4 animate-spin" />}
              {t.login.confirm}
            </Button>
            <Button type="button" variant="outline" disabled={pending} onClick={send}>
              {t.login.resend}
            </Button>
          </>
        ) : mode === "signup" ? (
          <Button type="button" disabled={pending || !email.trim()} onClick={create}>
            {pending && <Loader2 className="size-4 animate-spin" />}
            {t.login.createAndSend}
          </Button>
        ) : (
          <Button type="button" disabled={pending || !email.trim()} onClick={send}>
            {pending && <Loader2 className="size-4 animate-spin" />}
            {t.login.sendCode}
          </Button>
        )}
      </div>

      {!codeStep && (
        <button
          type="button"
          className="text-sm text-primary underline-offset-4 hover:underline"
          onClick={() => {
            setMode(mode === "signin" ? "signup" : "signin");
            setError(null);
          }}
        >
          {mode === "signin" ? t.login.createAccount : t.login.haveAccount}
        </button>
      )}
    </div>
  );
}
