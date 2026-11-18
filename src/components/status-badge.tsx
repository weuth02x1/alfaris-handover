import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import type { HandoverStatus, TaskStatus } from "@/lib/types";

const handoverTone: Record<HandoverStatus, string> = {
  draft: "bg-slate-100 text-slate-700 border-slate-200",
  pending_acceptance: "bg-amber-50 text-amber-800 border-amber-200",
  pending_manager: "bg-sky-50 text-sky-800 border-sky-200",
  pending_hr: "bg-violet-50 text-violet-800 border-violet-200",
  returned: "bg-rose-50 text-rose-800 border-rose-200",
  approved: "bg-emerald-50 text-emerald-800 border-emerald-200",
};

const taskTone: Record<TaskStatus, string> = {
  draft: "bg-slate-100 text-slate-700 border-slate-200",
  pending: "bg-amber-50 text-amber-800 border-amber-200",
  accepted: "bg-emerald-50 text-emerald-800 border-emerald-200",
  rejected: "bg-rose-50 text-rose-800 border-rose-200",
};

export function HandoverStatusBadge({ status, label }: { status: HandoverStatus; label: string }) {
  return (
    <Badge variant="outline" className={cn("font-medium", handoverTone[status])}>
      {label}
    </Badge>
  );
}

export function TaskStatusBadge({ status, label }: { status: TaskStatus; label: string }) {
  return (
    <Badge variant="outline" className={cn("font-medium", taskTone[status])}>
      {label}
    </Badge>
  );
}
