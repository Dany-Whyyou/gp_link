import { createBrowserClient } from "@supabase/ssr";

// Public Supabase creds - safe to inline (anon key only works with RLS policies).
// Falls back to env vars if present (for local dev override).
const SUPABASE_URL =
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://vppdjobdmeuoqnqlxaez.supabase.co";
const SUPABASE_ANON_KEY =
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwcGRqb2JkbWV1b3FucWx4YWV6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzODA5OTQsImV4cCI6MjA5MTk1Njk5NH0.g9Sw7q7Hl3gZzYlaXb4h6omBEs2goUS6viCzZU-2k70";

export function createClient() {
  return createBrowserClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}
