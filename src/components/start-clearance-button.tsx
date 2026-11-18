"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Loader2, Play } from "lucide-react";
import { startClearanceAction } from "@/app/actions";
import { Button } from "@/components/ui/button";

export function StartClearanceButton({
  requestRef,
  label,
  errorLabel,
  doneLabel,
}: {
  requestRef: string;
  label: string;
  errorLabel: string;
  doneLabel: string;
}) {
  const [pending, start] = useTransition();
  const router = useRouter();
  return (
    <Button
      size="sm"
      disabled={pending}
      onClick={() =>
        start(async () => {
          const res = await startClearanceAction(requestRef);
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
  );
}
