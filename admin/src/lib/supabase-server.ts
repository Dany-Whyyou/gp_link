import { createClient } from "@supabase/supabase-js";

/**
 * Admin Supabase client using service_role key.
 * Bypasses RLS for admin operations.
 * Only use server-side (API routes, server components, server actions).
 */
export function createAdminClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}
