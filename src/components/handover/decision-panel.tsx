"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Check, Loader2, Undo2 } from "lucide-react";
import { hrDecisionAction, managerDecisionAction } from "@/app/actions";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { Dict } from "@/lib/i18n/dict";
import { errorText } from "./errors";

export function DecisionPanel({ handoverId, kind, t }: { handoverId: string; kind: "manager" | "hr"; t: Dict }) {
  const [comment, setComment] = useState("");
  const [pending, start] = useTransition();
  const [which, setWhich] = useState<"approve" | "reject" | null>(null);
  const router = useRouter();

  const decide = (approve: boolean) => {
    if (!approve && !comment.trim()) {
      toast.error(t.errors.commentRequired);
      return;
    }
    setWhich(approve ? "approve" : "reject");
    start(async () => {
      const action = kind === "manager" ? managerDecisionAction : hrDecisionAction;
      const res = await action(handoverId, approve, comment);
      if (res.ok) {
        const key = `${kind}_${approve ? "approved" : "rejected"}` as const;
        toast.success(t.audit[key]);
        router.refresh();
      } else toast.error(errorText(t, res.error));
      setWhich(null);
    });
  };

  return (
    <Card className="border-primary/40 ring-2 ring-primary/10">
      <CardHeader>
        <CardTitle>{kind === "manager" ? t.form.managerReview : t.form.hrReview}</CardTitle>
        <CardDescription>{kind === "manager" ? t.form.managerReviewHint : t.form.hrReviewHint}</CardDescription>
      </CardHeader>
      <CardContent className="space-y-3">
        <div className="space-y-1.5">
          <Label htmlFor="decision-comment">
            {t.form.approvalComment} / {t.form.rejectionComment}
          </Label>
          <Textarea id="decision-comment" rows={3} value={comment} onChange={(e) => setComment(e.target.value)} />
        </div>
        <div className="flex flex-wrap justify-end gap-2">
          <Button variant="outline" className="text-rose-700" disabled={pending} onClick={() => decide(false)}>
            {pending && which === "reject" ? <Loader2 className="size-4 animate-spin" /> : <Undo2 className="size-4" />}
            {t.form.rejectAndReturn}
          </Button>
          <Button disabled={pending} onClick={() => decide(true)}>
            {pending && which === "approve" ? <Loader2 className="size-4 animate-spin" /> : <Check className="size-4" />}
            {t.form.approve}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
