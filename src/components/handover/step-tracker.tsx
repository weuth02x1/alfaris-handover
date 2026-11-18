import { Check } from "lucide-react";
import { cn } from "@/lib/utils";
import type { HandoverStatus } from "@/lib/types";

const order: HandoverStatus[] = ["draft", "pending_acceptance", "pending_manager", "pending_hr", "approved"];

export function StepTracker({
  status,
  labels,
}: {
  status: HandoverStatus;
  labels: [string, string, string, string, string];
}) {
  const current = status === "returned" ? 0 : order.indexOf(status);
  return (
    <ol className="grid grid-cols-5 gap-2">
      {labels.map((label, i) => {
        const done = i < current || status === "approved";
        const active = i === current && status !== "approved";
        return (
          <li key={label} className="flex flex-col items-center gap-1.5 text-center">
            <div className="flex w-full items-center">
              <span className={cn("h-0.5 flex-1", i === 0 ? "invisible" : done || active ? "bg-primary" : "bg-border")} />
              <span
                className={cn(
                  "grid size-8 shrink-0 place-items-center rounded-full border-2 text-xs font-semibold",
                  done && "border-primary bg-primary text-primary-foreground",
                  active && "border-primary bg-background text-primary ring-4 ring-primary/15",
                  !done && !active && "border-border bg-background text-muted-foreground",
                  active && status === "returned" && "border-rose-500 text-rose-600 ring-rose-500/15",
                )}
              >
                {done ? <Check className="size-4" /> : i + 1}
              </span>
              <span className={cn("h-0.5 flex-1", i === labels.length - 1 ? "invisible" : done ? "bg-primary" : "bg-border")} />
            </div>
            <span className={cn("text-[11px] leading-tight sm:text-xs", active ? "font-semibold" : "text-muted-foreground")}>
              {label}
            </span>
          </li>
        );
      })}
    </ol>
  );
}
