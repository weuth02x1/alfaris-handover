import "server-only";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

/** Project the handover app sends sign-in codes through. */
const PROJECT_URL = "https://sfshhcfjowiptefesqgp.supabase.co";

/** Server-side Supabase client. The publishable key stays on the server. */
export function supabase(): SupabaseClient | null {
  const url = process.env.SUPABASE_URL || PROJECT_URL;
  const key = process.env.SUPABASE_ANON_KEY;
  if (!key) return null;
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}

export function supabaseConfigured() {
  return Boolean(process.env.SUPABASE_ANON_KEY);
}
