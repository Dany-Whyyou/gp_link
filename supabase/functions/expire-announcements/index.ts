// supabase/functions/expire-announcements/index.ts
// Edge Function: Expire announcements past their expiry date
// Called via pg_cron (every hour) or external cron scheduler

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.50.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req: Request) => {
  // Allow GET (for cron) and POST
  if (req.method !== "POST" && req.method !== "GET") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Verify authorization for cron calls
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const now = new Date().toISOString();

    // Find all announcements that should be expired
    const { data: expiredAnnouncements, error: fetchError } = await supabase
      .from("announcements")
      .select("id, user_id, departure_city, arrival_city, departure_date")
      .eq("status", "active")
      .lt("expires_at", now);

    if (fetchError) {
      console.error("Error fetching expired announcements:", fetchError);
      return new Response(
        JSON.stringify({ error: "Error fetching announcements" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    if (!expiredAnnouncements || expiredAnnouncements.length === 0) {
      console.log("No announcements to expire");
      return new Response(
        JSON.stringify({ expired: 0 }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    console.log(`Found ${expiredAnnouncements.length} announcements to expire`);

    const expiredIds = expiredAnnouncements.map((a) => a.id);

    // Batch update all expired announcements
    const { error: updateError } = await supabase
      .from("announcements")
      .update({ status: "expired" })
      .in("id", expiredIds);

    if (updateError) {
      console.error("Error updating announcement statuses:", updateError);
      return new Response(
        JSON.stringify({ error: "Error expiring announcements" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    // Send notifications to announcement owners
    const notifications = expiredAnnouncements.map((ann) => ({
      user_id: ann.user_id,
      type: "system" as const,
      title: "Annonce expiree",
      body: `Votre annonce ${ann.departure_city} -> ${ann.arrival_city} du ${ann.departure_date} a expire. Vous pouvez la renouveler.`,
      data: {
        announcement_id: ann.id,
        action: "renew",
      },
    }));

    const { error: notifError } = await supabase
      .from("notifications")
      .insert(notifications);

    if (notifError) {
      console.error("Error creating expiry notifications:", notifError);
      // Don't fail the whole operation for notification errors
    }

    // Also expire alerts that have passed their expiry date
    const { data: expiredAlerts, error: alertError } = await supabase
      .from("alerts")
      .select("id")
      .eq("status", "active")
      .lt("expires_at", now);

    let expiredAlertCount = 0;
    if (!alertError && expiredAlerts && expiredAlerts.length > 0) {
      const alertIds = expiredAlerts.map((a) => a.id);
      const { error: alertUpdateError } = await supabase
        .from("alerts")
        .update({ status: "expired" })
        .in("id", alertIds);

      if (alertUpdateError) {
        console.error("Error expiring alerts:", alertUpdateError);
      } else {
        expiredAlertCount = alertIds.length;
      }
    }

    console.log(
      `Expired ${expiredIds.length} announcements and ${expiredAlertCount} alerts`,
    );

    return new Response(
      JSON.stringify({
        expired_announcements: expiredIds.length,
        expired_alerts: expiredAlertCount,
        announcement_ids: expiredIds,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("Unexpected error in expire-announcements:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
