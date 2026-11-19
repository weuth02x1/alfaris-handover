"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Loader2, Play } from "lucide-react";
import { startClearanceAction } from "@/app/actions";
import { Button } from "@/components/ui/button";

export function StartClearanceButton({
  requestRef,
  defaultReason,
  reasons,
  label,
  errorLabel,
  doneLabel,
}: {
  requestRef: string;
  defaultReason: string;
  reasons: { value: string; label: string }[];
  label: string;
  errorLabel: string;
  doneLabel: string;
}) {
  const [pending, start] = useTransition();
  const [reason, setReason] = useState(defaultReason);
  const router = useRouter();
  return (
    <div className="flex flex-col items-stretch gap-2 sm:items-end">
      <select
        value={reason}
        onChange={(event) => setReason(event.target.value)}
        className="h-8 rounded-lg border bg-card px-2 text-xs"
        aria-label={label}
      >
        {reasons.map((item) => (
          <option key={item.value} value={item.value}>
            {item.label}
          </option>
        ))}
      </select>
      <Button
        size="sm"
        disabled={pending}
        onClick={() =>
          start(async () => {
            const res = await startClearanceAction(requestRef, reason);
            if (res.ok) {
              toast.success(doneLabel);
              router.refresh();
            } else toast.error(errorLabel);
          })
        }
      >
        {pending ? <Loader2 className="size-4 animate-spin" /> : <Play className="size-4 rtl:-scale-x-100" />}
        {label}
      </Button>
    </div>
  );
}
