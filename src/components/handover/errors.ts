import type { Dict } from "@/lib/i18n/dict";
import type { WorkflowErrorCode } from "@/lib/workflow";

export function errorText(t: Dict, code: WorkflowErrorCode) {
  if (code === "noTasks") return t.form.noTasks;
  return t.errors[code];
}
