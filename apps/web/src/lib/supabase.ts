import { createClient, type SupabaseClient } from '@supabase/supabase-js';

// Browser/client Supabase. Server-side queue ops use the worker's service-role client.
const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const supabaseConfigured = Boolean(url && anon);

let _client: SupabaseClient | null = null;

/** Returns the browser client; throws if env isn't configured yet (S0/S1 guard). */
export function getSupabase(): SupabaseClient {
  if (!supabaseConfigured) {
    throw new Error('Supabase not configured — set NEXT_PUBLIC_SUPABASE_URL/ANON_KEY in .env.local');
  }
  if (!_client) _client = createClient(url!, anon!, { auth: { persistSession: true } });
  return _client;
}
