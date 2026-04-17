// supabase/functions/cleanup-notifications/index.ts
// Edge Function: Clean up old notifications
// - Deletes read notifications older than 30 days
// - Deletes unread notifications older than 90 days
// Called via pg_cron (daily) or external cron scheduler

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.50.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const READ_RETENTION_DAYS = 30;
const UNREAD_RETENTION_DAYS = 90;

serve(async (req: Request) => {
  // Allow GET (for cron) and POST
  if (req.method !== "POST" && req.method !== "GET") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Verify authorization
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const now = new Date();

    // Calculate cutoff dates
    const readCutoff = new Date(now);
    readCutoff.setDate(readCutoff.getDate() - READ_RETENTION_DAYS);

    const unreadCutoff = new Date(now);
    unreadCutoff.setDate(unreadCutoff.getDate() - UNREAD_RETENTION_DAYS);

    // Delete read notifications older than 30 days
    const { count: readDeletedCount, error: readError } = await supabase
      .from("notifications")
      .delete({ count: "exact" })
      .eq("is_read", true)
      .lt("created_at", readCutoff.toISOString());

    if (readError) {
      console.error("Error deleting old read notifications:", readError);
    } else {
      console.log(`Deleted ${readDeletedCount ?? 0} read notifications older than ${READ_RETENTION_DAYS} days`);
    }

    // Delete unread notifications older than 90 days
    const { count: unreadDeletedCount, error: unreadError } = await supabase
      .from("notifications")
      .delete({ count: "exact" })
      .eq("is_read", false)
      .lt("created_at", unreadCutoff.toISOString());

    if (unreadError) {
      console.error("Error deleting old unread notifications:", unreadError);
    } else {
      console.log(`Deleted ${unreadDeletedCount ?? 0} unread notifications older than ${UNREAD_RETENTION_DAYS} days`);
    }

    const totalDeleted = (readDeletedCount ?? 0) + (unreadDeletedCount ?? 0);

    return new Response(
      JSON.stringify({
        deleted_total: totalDeleted,
        deleted_read: readDeletedCount ?? 0,
        deleted_unread: unreadDeletedCount ?? 0,
        read_cutoff: readCutoff.toISOString(),
        unread_cutoff: unreadCutoff.toISOString(),
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("Unexpected error in cleanup-notifications:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
