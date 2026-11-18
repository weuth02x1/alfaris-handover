"use client";

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

export interface PersonOption {
  id: string;
  label: string;
  sub: string;
}

export function AssigneeSelect({
  value,
  onChange,
  options,
  placeholder,
  disabledIds = [],
  id,
}: {
  value: string;
  onChange: (v: string) => void;
  options: PersonOption[];
  placeholder: string;
  disabledIds?: string[];
  id?: string;
}) {
  const items = options.map((o) => ({ value: o.id, label: o.label }));
  return (
    <Select items={items} value={value || null} onValueChange={(v) => onChange((v as string | null) ?? "")}>
      <SelectTrigger id={id} className="w-full">
        <SelectValue placeholder={placeholder} />
      </SelectTrigger>
      <SelectContent>
        {options.map((o) => (
          <SelectItem key={o.id} value={o.id} disabled={disabledIds.includes(o.id)}>
            <span className="flex flex-col items-start">
              <span>{o.label}</span>
              <span className="text-xs text-muted-foreground">{o.sub}</span>
            </span>
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
