/** Only same-site relative paths. Rejects protocol, host, and scheme tricks. */
export function safeNext(value: string | null | undefined): string {
  if (!value) return "/";
  let path = value;
  try {
    path = decodeURIComponent(value);
  } catch {
    return "/";
  }
  if (!path.startsWith("/") || path.startsWith("//") || path.startsWith("/\\")) return "/";
  if (/[\u0000-\u001f\u007f\\:]/.test(path) || path.includes("//")) return "/";
  return path;
}
