import "server-only";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

/** Server-side Supabase client. Both values come from the environment, never from the source. */
export function supabase(): SupabaseClient | null {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY;
  if (!url || !key) return null;
  try {
    if (new URL(url).protocol !== "https:") return null;
  } catch {
    return null;
  }
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    global: {
      fetch: (input, init) => fetch(input, { ...init, signal: AbortSignal.timeout(6_000) }),
    },
  });
}

export function supabaseConfigured() {
  return supabase() !== null;
}
