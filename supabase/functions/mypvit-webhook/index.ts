// Edge Function: mypvit-webhook
// Receives payment status callbacks from MyPvit (CALLBACK code).
// Protected by token in query param (MyPvit does not support custom headers).
// Deploy with: supabase functions deploy mypvit-webhook --no-verify-jwt

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MYPVIT_WEBHOOK_TOKEN = Deno.env.get("MYPVIT_WEBHOOK_TOKEN")!;

const ANNOUNCEMENT_DURATION_DAYS = 7;

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

interface PaymentCallback {
  transactionId?: string;
  merchantReferenceId?: string;
  status?: string;
  amount?: number | string;
  operator?: string;
  code?: number;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
      },
    });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const url = new URL(req.url);
  const token = url.searchParams.get("token") ?? "";
  if (!timingSafeEqual(token, MYPVIT_WEBHOOK_TOKEN)) {
    console.warn("mypvit-webhook: token verification failed");
    return jsonResponse({ error: "Forbidden" }, 403);
  }

  let payload: PaymentCallback;
  try {
    payload = await req.json();
  } catch (e) {
    console.error("mypvit-webhook: invalid JSON", e);
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const { transactionId, merchantReferenceId, status } = payload;
  if (!transactionId && !merchantReferenceId) {
    return jsonResponse({ error: "Missing identifiers" }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // MyPvit strips dashes from references: "GPL-abc-123" becomes "GPLabc123"
  // We search by both the mypvit transaction ID and the reference (normalized)
  const refCandidates: string[] = [];
  if (merchantReferenceId) {
    refCandidates.push(merchantReferenceId);
    refCandidates.push(merchantReferenceId.replace(/-/g, ""));
  }

  let payment: Record<string, any> | null = null;
  if (transactionId) {
    const { data } = await supabase
      .from("payments")
      .select("*")
      .eq("mypvit_transaction_id", transactionId)
      .maybeSingle();
    payment = data;
  }
  if (!payment && refCandidates.length > 0) {
    const { data } = await supabase
      .from("payments")
      .select("*")
      .in("reference", refCandidates)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    payment = data;
  }

  if (!payment) {
    console.warn("mypvit-webhook: payment not found", { transactionId, merchantReferenceId });
    return jsonResponse({ responseCode: 200, message: "Payment not found (silent)" }, 200);
  }

  if (payment.status === "completed" || payment.status === "failed") {
    console.log(`mypvit-webhook: payment ${payment.id} already ${payment.status}`);
    return jsonResponse({ responseCode: 200, transactionId: transactionId ?? null }, 200);
  }

  const normalizedStatus = (status ?? "").toUpperCase();
  if (normalizedStatus === "SUCCESS" || normalizedStatus === "ACCEPTED") {
    await handleSuccess(supabase, payment, payload);
  } else if (normalizedStatus === "FAILED" || normalizedStatus === "REFUSED" || normalizedStatus === "CANCELLED") {
    await handleFailure(supabase, payment, payload);
  } else {
    console.log(`mypvit-webhook: payment ${payment.id} status pending (${normalizedStatus})`);
  }

  return jsonResponse({ responseCode: 200, transactionId: transactionId ?? null }, 200);
});

async function handleSuccess(
  supabase: ReturnType<typeof createClient>,
  payment: Record<string, any>,
  callback: PaymentCallback,
): Promise<void> {
  const now = new Date();
  const { error: updateError } = await supabase
    .from("payments")
    .update({
      status: "completed",
      paid_at: now.toISOString(),
      mypvit_transaction_id: callback.transactionId ?? payment.mypvit_transaction_id,
      payment_method: "mobile_money",
      operator: callback.operator ?? payment.operator,
      metadata: {
        ...(payment.metadata ?? {}),
        mypvit_callback: callback,
        verified_at: now.toISOString(),
      },
    })
    .eq("id", payment.id)
    .neq("status", "completed");

  if (updateError) {
    console.error("mypvit-webhook: update failed", updateError);
    throw updateError;
  }

  if (payment.announcement_id) {
    const expiresAt = new Date(now);
    expiresAt.setDate(expiresAt.getDate() + ANNOUNCEMENT_DURATION_DAYS);

    const updateData: Record<string, any> = {};

    if (payment.type === "extension") {
      const { data: currentAnn } = await supabase
        .from("announcements")
        .select("expires_at")
        .eq("id", payment.announcement_id)
        .single();
      if (currentAnn?.expires_at) {
        const current = new Date(currentAnn.expires_at);
        const base = new Date(Math.max(current.getTime(), now.getTime()));
        base.setDate(base.getDate() + ANNOUNCEMENT_DURATION_DAYS);
        updateData.expires_at = base.toISOString();
      } else {
        updateData.expires_at = expiresAt.toISOString();
      }
    } else {
      updateData.status = "active";
      updateData.published_at = now.toISOString();
      updateData.expires_at = expiresAt.toISOString();
      if (payment.type === "boost") updateData.type = "boosted";
    }

    const { error: annError } = await supabase
      .from("announcements")
      .update(updateData)
      .eq("id", payment.announcement_id);

    if (annError) {
      console.error("mypvit-webhook: announcement update failed", annError);
      await supabase.from("payments").update({ needs_review: true }).eq("id", payment.id);
    } else if (payment.type === "announcement" || payment.type === "boost") {
      try {
        await fetch(`${SUPABASE_URL}/functions/v1/match-alerts`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          },
          body: JSON.stringify({ announcement_id: payment.announcement_id }),
        });
      } catch (e) {
        console.error("mypvit-webhook: match-alerts trigger failed", e);
      }
    }
  }

  await supabase.from("notifications").insert({
    user_id: payment.user_id,
    type: "payment",
    title: "Paiement confirme",
    body: `Votre paiement de ${payment.amount} FCFA a ete confirme. Votre annonce est active.`,
    data: {
      payment_id: payment.id,
      announcement_id: payment.announcement_id,
      amount: payment.amount,
    },
  });
}

async function handleFailure(
  supabase: ReturnType<typeof createClient>,
  payment: Record<string, any>,
  callback: PaymentCallback,
): Promise<void> {
  const now = new Date();
  const { error } = await supabase
    .from("payments")
    .update({
      status: "failed",
      failed_at: now.toISOString(),
      metadata: {
        ...(payment.metadata ?? {}),
        mypvit_callback: callback,
        failed_at: now.toISOString(),
      },
    })
    .eq("id", payment.id)
    .neq("status", "failed");

  if (error) {
    console.error("mypvit-webhook: failure update error", error);
    throw error;
  }

  await supabase.from("notifications").insert({
    user_id: payment.user_id,
    type: "payment",
    title: "Echec du paiement",
    body: `Votre paiement de ${payment.amount} FCFA a echoue. Vous pouvez reessayer.`,
    data: {
      payment_id: payment.id,
      announcement_id: payment.announcement_id,
      amount: payment.amount,
    },
  });
}
