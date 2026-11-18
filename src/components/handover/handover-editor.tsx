"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Loader2, Plus, Save, Send, Trash2 } from "lucide-react";
import { saveHandoverAction } from "@/app/actions";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { Dict } from "@/lib/i18n/dict";
import { AssigneeSelect, type PersonOption } from "./assignee-select";
import { errorText } from "./errors";

interface EditableTask {
  key: string;
  id?: string;
  title: string;
  details: string;
  dueDate: string;
  assigneeId: string;
  accepted?: boolean;
}

let seq = 0;
const blank = (): EditableTask => ({ key: `new-${++seq}`, title: "", details: "", dueDate: "", assigneeId: "" });

export function HandoverEditor({
  handoverId,
  t,
  colleagues,
  initialNotes,
  initialTasks,
}: {
  handoverId: string;
  t: Dict;
  colleagues: PersonOption[];
  initialNotes: string;
  initialTasks: Omit<EditableTask, "key">[];
}) {
  const [notes, setNotes] = useState(initialNotes);
  const [tasks, setTasks] = useState<EditableTask[]>(
    initialTasks.length ? initialTasks.map((x) => ({ ...x, key: x.id ?? `k-${++seq}` })) : [blank()],
  );
  const [pending, start] = useTransition();
  const [mode, setMode] = useState<"save" | "submit" | null>(null);
  const router = useRouter();

  const update = (key: string, patch: Partial<EditableTask>) =>
    setTasks((ts) => ts.map((x) => (x.key === key ? { ...x, ...patch } : x)));

  const send = (submit: boolean) => {
    setMode(submit ? "submit" : "save");
    start(async () => {
      const res = await saveHandoverAction(
        handoverId,
        {
          generalNotes: notes,
          tasks: tasks.map((x) => ({
            id: x.id,
            title: x.title,
            details: x.details,
            dueDate: x.dueDate || null,
            assigneeId: x.assigneeId,
          })),
        },
        submit,
      );
      if (res.ok) {
        toast.success(submit ? t.audit.form_submitted : t.audit.form_saved);
        router.refresh();
      } else toast.error(errorText(t, res.error));
      setMode(null);
    });
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t.form.tasks}</CardTitle>
        <CardDescription>{t.form.tasksHint}</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {tasks.map((task, i) => (
          <div key={task.key} className="space-y-3 rounded-xl border bg-muted/30 p-4">
            <div className="flex items-center justify-between gap-2">
              <span className="text-sm font-semibold text-muted-foreground">
                {t.form.taskTitle} {i + 1}
              </span>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={() => setTasks((ts) => ts.filter((x) => x.key !== task.key))}
                disabled={tasks.length === 1}
              >
                <Trash2 className="size-4" />
                {t.form.removeTask}
              </Button>
            </div>
            <div className="grid gap-3 md:grid-cols-2">
              <div className="space-y-1.5 md:col-span-2">
                <Label htmlFor={`title-${task.key}`}>{t.form.taskTitle}</Label>
                <Input
                  id={`title-${task.key}`}
                  value={task.title}
                  placeholder={t.form.taskTitlePh}
                  onChange={(e) => update(task.key, { title: e.target.value })}
                />
              </div>
              <div className="space-y-1.5 md:col-span-2">
                <Label htmlFor={`details-${task.key}`}>{t.form.taskDetails}</Label>
                <Textarea
                  id={`details-${task.key}`}
                  value={task.details}
                  rows={3}
                  placeholder={t.form.taskDetailsPh}
                  onChange={(e) => update(task.key, { details: e.target.value })}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor={`assignee-${task.key}`}>{t.form.assignee}</Label>
                <AssigneeSelect
                  id={`assignee-${task.key}`}
                  value={task.assigneeId}
                  onChange={(v) => update(task.key, { assigneeId: v })}
                  options={colleagues}
                  placeholder={t.form.chooseAssignee}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor={`due-${task.key}`}>{t.form.dueDate}</Label>
                <Input
                  id={`due-${task.key}`}
                  type="date"
                  value={task.dueDate}
                  onChange={(e) => update(task.key, { dueDate: e.target.value })}
                />
              </div>
            </div>
          </div>
        ))}

        <Button type="button" variant="outline" onClick={() => setTasks((ts) => [...ts, blank()])}>
          <Plus className="size-4" />
          {t.form.addTask}
        </Button>

        <div className="space-y-1.5 pt-2">
          <Label htmlFor="notes">{t.form.generalNotes}</Label>
          <Textarea
            id="notes"
            rows={3}
            value={notes}
            placeholder={t.form.generalNotesPh}
            onChange={(e) => setNotes(e.target.value)}
          />
        </div>

        <div className="flex flex-wrap justify-end gap-2 border-t pt-4">
          <Button type="button" variant="outline" disabled={pending} onClick={() => send(false)}>
            {pending && mode === "save" ? <Loader2 className="size-4 animate-spin" /> : <Save className="size-4" />}
            {t.form.saveDraft}
          </Button>
          <Button type="button" disabled={pending} onClick={() => send(true)}>
            {pending && mode === "submit" ? (
              <Loader2 className="size-4 animate-spin" />
            ) : (
              <Send className="size-4 rtl:-scale-x-100" />
            )}
            {t.form.submit}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
