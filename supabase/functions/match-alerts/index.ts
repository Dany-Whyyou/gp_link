// supabase/functions/match-alerts/index.ts
// Edge Function: Match active alerts against a newly activated announcement
// Triggered after an announcement becomes active (called by process-payment)

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID")!;
const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY")!;

const MAX_NOTIFICATIONS_PER_ALERT_PER_DAY = 3;

interface MatchAlertRequest {
  announcement_id: string;
}

interface AlertMatch {
  alert_id: string;
  user_id: string;
}

serve(async (req: Request) => {
  // Only allow POST
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const { announcement_id } = (await req.json()) as MatchAlertRequest;

    if (!announcement_id) {
      return new Response(
        JSON.stringify({ error: "announcement_id is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // Use service role client to bypass RLS
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Fetch the announcement details
    const { data: announcement, error: annError } = await supabase
      .from("announcements")
      .select("*")
      .eq("id", announcement_id)
      .eq("status", "active")
      .single();

    if (annError || !announcement) {
      console.error("Announcement not found or not active:", annError);
      return new Response(
        JSON.stringify({ error: "Announcement not found or not active" }),
        { status: 404, headers: { "Content-Type": "application/json" } },
      );
    }

    // Use the database function to find matching alerts
    const { data: matches, error: matchError } = await supabase.rpc(
      "match_alerts_for_announcement",
      { p_announcement_id: announcement_id },
    );

    if (matchError) {
      console.error("Error matching alerts:", matchError);
      return new Response(
        JSON.stringify({ error: "Error matching alerts" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    if (!matches || matches.length === 0) {
      console.log(`No matching alerts for announcement ${announcement_id}`);
      return new Response(
        JSON.stringify({ matched: 0 }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    console.log(`Found ${matches.length} matching alerts for announcement ${announcement_id}`);

    const notificationResults = [];
    const playerIdsToNotify: string[] = [];
    const today = new Date().toISOString().split("T")[0];

    for (const match of matches as AlertMatch[]) {
      // Anti-spam: check how many notifications this alert already sent today
      const { count: todayCount } = await supabase
        .from("notifications")
        .select("*", { count: "exact", head: true })
        .eq("user_id", match.user_id)
        .eq("type", "alert_match")
        .gte("created_at", `${today}T00:00:00Z`);

      if ((todayCount ?? 0) >= MAX_NOTIFICATIONS_PER_ALERT_PER_DAY) {
        console.log(`Skipping user ${match.user_id}: daily notification limit reached`);
        continue;
      }

      // Check for duplicate notification (same announcement + same user)
      const { count: duplicateCount } = await supabase
        .from("notifications")
        .select("*", { count: "exact", head: true })
        .eq("user_id", match.user_id)
        .eq("type", "alert_match")
        .contains("data", { announcement_id });

      if ((duplicateCount ?? 0) > 0) {
        console.log(`Skipping user ${match.user_id}: duplicate notification`);
        continue;
      }

      // Create in-app notification
      const notificationTitle = "Nouvelle correspondance !";
      const notificationBody =
        `Un voyageur propose ${announcement.available_kg}kg ` +
        `${announcement.departure_city} -> ${announcement.arrival_city} ` +
        `le ${announcement.departure_date} a ${announcement.price_per_kg} FCFA/kg`;

      const { error: notifError } = await supabase
        .from("notifications")
        .insert({
          user_id: match.user_id,
          type: "alert_match",
          title: notificationTitle,
          body: notificationBody,
          data: {
            announcement_id,
            alert_id: match.alert_id,
            departure_city: announcement.departure_city,
            arrival_city: announcement.arrival_city,
            departure_date: announcement.departure_date,
            available_kg: announcement.available_kg,
            price_per_kg: announcement.price_per_kg,
          },
          is_pushed: false,
        });

      if (notifError) {
        console.error(`Error creating notification for user ${match.user_id}:`, notifError);
        continue;
      }

      // Get user's OneSignal player ID for push notification
      const { data: profile } = await supabase
        .from("profiles")
        .select("onesignal_player_id, full_name")
        .eq("id", match.user_id)
        .single();

      if (profile?.onesignal_player_id) {
        playerIdsToNotify.push(profile.onesignal_player_id);
      }

      // Update alert match stats
      await supabase
        .from("alerts")
        .update({
          match_count: (match as any).match_count
            ? (match as any).match_count + 1
            : 1,
          last_matched_at: new Date().toISOString(),
        })
        .eq("id", match.alert_id);

      notificationResults.push({
        alert_id: match.alert_id,
        user_id: match.user_id,
        notified: true,
      });
    }

    // Send push notifications via OneSignal in batch
    if (playerIdsToNotify.length > 0) {
      try {
        await sendOneSignalPush(
          playerIdsToNotify,
          "Nouvelle correspondance !",
          `${announcement.available_kg}kg ${announcement.departure_city} -> ${announcement.arrival_city} le ${announcement.departure_date}`,
          {
            type: "alert_match",
            announcement_id,
          },
        );

        // Mark notifications as pushed
        for (const result of notificationResults) {
          await supabase
            .from("notifications")
            .update({ is_pushed: true })
            .eq("user_id", result.user_id)
            .eq("type", "alert_match")
            .contains("data", { announcement_id });
        }
      } catch (pushError) {
        console.error("Error sending push notifications:", pushError);
        // Don't fail the whole function if push fails
      }
    }

    return new Response(
      JSON.stringify({
        matched: notificationResults.length,
        pushed: playerIdsToNotify.length,
        results: notificationResults,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("Unexpected error in match-alerts:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});

/**
 * Send push notification via OneSignal REST API
 */
async function sendOneSignalPush(
  playerIds: string[],
  title: string,
  message: string,
  data: Record<string, string>,
): Promise<void> {
  const response = await fetch("https://onesignal.com/api/v1/notifications", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
    },
    body: JSON.stringify({
      app_id: ONESIGNAL_APP_ID,
      include_player_ids: playerIds,
      headings: { en: title, fr: title },
      contents: { en: message, fr: message },
      data,
      android_channel_id: "gp-link-alerts",
      priority: 10,
      ttl: 86400, // 24 hours
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`OneSignal API error: ${response.status} - ${errorBody}`);
  }

  const result = await response.json();
  console.log(`OneSignal push sent to ${playerIds.length} devices, id: ${result.id}`);
}
