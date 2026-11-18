import { cn } from "@/lib/utils";

export function BrandLockup({
  className,
  markOnly = false,
}: {
  className?: string;
  markOnly?: boolean;
}) {
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={markOnly ? "/brand/alfaris-mark.png" : "/brand/alfaris-lockup.png"}
      alt="مجموعة الفارس Alfaris Group"
      className={cn("w-auto select-none", className)}
    />
  );
}
