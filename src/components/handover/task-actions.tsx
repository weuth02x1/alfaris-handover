"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Check, Loader2, Repeat, X } from "lucide-react";
import { acceptTaskAction, reassignTaskAction, rejectTaskAction, type ActionResult } from "@/app/actions";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { Dict } from "@/lib/i18n/dict";
import { AssigneeSelect, type PersonOption } from "./assignee-select";
import { errorText } from "./errors";

function useAction(t: Dict) {
  const [pending, start] = useTransition();
  const router = useRouter();
  const run = (fn: () => Promise<ActionResult>, success: string, after?: () => void) =>
    start(async () => {
      const res = await fn();
      if (res.ok) {
        toast.success(success);
        after?.();
        router.refresh();
      } else toast.error(errorText(t, res.error));
    });
  return { pending, run };
}

export function RecipientActions({
  handoverId,
  taskId,
  taskTitle,
  t,
}: {
  handoverId: string;
  taskId: string;
  taskTitle: string;
  t: Dict;
}) {
  const { pending, run } = useAction(t);
  const [note, setNote] = useState("");
  const [reason, setReason] = useState("");
  const [open, setOpen] = useState(false);

  return (
    <div className="space-y-3 rounded-lg border border-primary/30 bg-primary/5 p-3">
      <div className="space-y-1.5">
        <Label htmlFor={`note-${taskId}`}>{t.form.acceptNote}</Label>
        <Input id={`note-${taskId}`} value={note} onChange={(e) => setNote(e.target.value)} />
      </div>
      <div className="flex flex-wrap gap-2">
        <Button
          disabled={pending}
          onClick={() => run(() => acceptTaskAction(handoverId, taskId, note), t.audit.task_accepted)}
        >
          {pending ? <Loader2 className="size-4 animate-spin" /> : <Check className="size-4" />}
          {t.form.accept}
        </Button>
        <Button variant="outline" className="text-rose-700" disabled={pending} onClick={() => setOpen(true)}>
          <X className="size-4" />
          {t.form.reject}
        </Button>
      </div>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t.form.reject}</DialogTitle>
            <DialogDescription>{taskTitle}</DialogDescription>
          </DialogHeader>
          <div className="space-y-1.5">
            <Label htmlFor={`reason-${taskId}`}>{t.form.rejectReason}</Label>
            <Textarea
              id={`reason-${taskId}`}
              rows={4}
              value={reason}
              placeholder={t.form.rejectReasonPh}
              onChange={(e) => setReason(e.target.value)}
            />
          </div>
          <DialogFooter>
            <DialogClose render={<Button variant="outline" />}>{t.form.cancel}</DialogClose>
            <Button
              variant="destructive"
              disabled={pending || !reason.trim()}
              onClick={() =>
                run(() => rejectTaskAction(handoverId, taskId, reason), t.audit.task_rejected, () => setOpen(false))
              }
            >
              {pending && <Loader2 className="size-4 animate-spin" />}
              {t.form.confirmReject}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export function ReassignControl({
  handoverId,
  taskId,
  options,
  excludedIds,
  t,
}: {
  handoverId: string;
  taskId: string;
  options: PersonOption[];
  excludedIds: string[];
  t: Dict;
}) {
  const { pending, run } = useAction(t);
  const [assignee, setAssignee] = useState("");
  return (
    <div className="space-y-2 rounded-lg border border-rose-200 bg-rose-50/60 p-3">
      <Label htmlFor={`reassign-${taskId}`}>{t.form.newAssignee}</Label>
      <div className="flex flex-col gap-2 sm:flex-row">
        <div className="flex-1">
          <AssigneeSelect
            id={`reassign-${taskId}`}
            value={assignee}
            onChange={setAssignee}
            options={options}
            disabledIds={excludedIds}
            placeholder={t.form.chooseAssignee}
          />
        </div>
        <Button
          disabled={pending || !assignee}
          onClick={() => run(() => reassignTaskAction(handoverId, taskId, assignee), t.audit.task_reassigned)}
        >
          {pending ? <Loader2 className="size-4 animate-spin" /> : <Repeat className="size-4" />}
          {t.form.reassign}
        </Button>
      </div>
    </div>
  );
}
