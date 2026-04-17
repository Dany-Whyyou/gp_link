// Edge Function: mypvit-initiate
// Called by the mobile app to start a MyPvit payment.
// Handles secret rotation, amount derivation from app_config, and MyPvit /rest/payment call.
// Deploy with: supabase functions deploy mypvit-initiate (JWT required)

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const MYPVIT_BASE = "https://api.mypvit.pro";
const MYPVIT_PASSWORD = Deno.env.get("MYPVIT_PASSWORD")!;
const MYPVIT_AGENT = Deno.env.get("MYPVIT_AGENT")!;
const MYPVIT_ACCOUNT_AIRTEL = Deno.env.get("MYPVIT_ACCOUNT_AIRTEL")!;
const MYPVIT_ACCOUNT_MOOV = Deno.env.get("MYPVIT_ACCOUNT_MOOV")!;
const MYPVIT_ACCOUNT_TEST = Deno.env.get("MYPVIT_ACCOUNT_TEST")!;
const MYPVIT_CALLBACK_CODE = Deno.env.get("MYPVIT_CALLBACK_CODE")!;
const MYPVIT_RECEPTION_CODE = Deno.env.get("MYPVIT_RECEPTION_CODE")!;
const MYPVIT_RENEW_SECRET_CODE = Deno.env.get("MYPVIT_RENEW_SECRET_CODE")!;
const MYPVIT_REST_CODE = Deno.env.get("MYPVIT_REST_CODE")!;

const SECRET_TTL_SAFETY_SECONDS = 120;
const SECRET_WAIT_TIMEOUT_MS = 15000;
const SECRET_POLL_INTERVAL_MS = 500;

type Operator = "AIRTEL_MONEY" | "MOOV_MONEY" | "TEST";
type PaymentType = "announcement" | "boost" | "extension" | "extra_announcement";

interface InitiateRequest {
  announcement_id: string;
  payment_type: PaymentType;
  operator: Operator;
  phone_number: string;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

function accountForOperator(op: Operator): string {
  switch (op) {
    case "AIRTEL_MONEY": return MYPVIT_ACCOUNT_AIRTEL;
    case "MOOV_MONEY": return MYPVIT_ACCOUNT_MOOV;
    case "TEST": return MYPVIT_ACCOUNT_TEST;
  }
}

async function getCachedSecret(supabase: ReturnType<typeof createClient>): Promise<string | null> {
  const cutoff = new Date(Date.now() + SECRET_TTL_SAFETY_SECONDS * 1000).toISOString();
  const { data } = await supabase
    .from("mypvit_secrets")
    .select("secret, expires_at")
    .eq("id", "current")
    .maybeSingle();
  if (!data) return null;
  if (data.expires_at < cutoff) return null;
  return data.secret as string;
}

async function triggerRenewSecret(): Promise<void> {
  const body = new URLSearchParams({
    operationAccountCode: MYPVIT_ACCOUNT_MOOV,
    password: MYPVIT_PASSWORD,
    receptionUrlCode: MYPVIT_RECEPTION_CODE,
  });
  const res = await fetch(`${MYPVIT_BASE}/${MYPVIT_RENEW_SECRET_CODE}/renew-secret`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`renew-secret failed: ${res.status} ${text}`);
  }
}

async function waitForSecret(supabase: ReturnType<typeof createClient>): Promise<string> {
  const deadline = Date.now() + SECRET_WAIT_TIMEOUT_MS;
  while (Date.now() < deadline) {
    const s = await getCachedSecret(supabase);
    if (s) return s;
    await new Promise((r) => setTimeout(r, SECRET_POLL_INTERVAL_MS));
  }
  throw new Error("Timeout waiting for MyPvit secret via webhook");
}

async function ensureSecret(supabase: ReturnType<typeof createClient>): Promise<string> {
  const cached = await getCachedSecret(supabase);
  if (cached) return cached;
  await triggerRenewSecret();
  return await waitForSecret(supabase);
}

async function callInitiatePayment(
  secret: string,
  params: {
    amount: number;
    reference: string;
    phone: string;
    operator: Operator;
    account: string;
    productLabel: string;
  },
): Promise<{ ok: boolean; status: number; body: any }> {
  const res = await fetch(`${MYPVIT_BASE}/v2/${MYPVIT_REST_CODE}/rest`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Secret": secret,
    },
    body: JSON.stringify({
      agent: MYPVIT_AGENT,
      amount: params.amount,
      reference: params.reference,
      service: "RESTFUL",
      callback_url_code: MYPVIT_CALLBACK_CODE,
      customer_account_number: params.phone,
      merchant_operation_account_code: params.account,
      transaction_type: "PAYMENT",
      operator_code: params.operator,
      owner_charge: "CUSTOMER",
      owner_charge_operator: "CUSTOMER",
      free_info: "GP Link",
      product: params.productLabel,
    }),
  });
  const body = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, body };
}

function generateReference(userId: string): string {
  const short = userId.replace(/-/g, "").slice(0, 8);
  const ts = Date.now().toString();
  return `GPL${short}${ts}`;
}

async function resolveAmount(
  supabase: ReturnType<typeof createClient>,
  paymentType: PaymentType,
  userId: string,
): Promise<number> {
  const keyByType: Record<PaymentType, string> = {
    announcement: "price_standard",
    boost: "price_boosted",
    extension: "price_extension",
    extra_announcement: "price_extra_announcement",
  };
  const defaultByType: Record<PaymentType, number> = {
    announcement: 1500,
    boost: 3000,
    extension: 1000,
    extra_announcement: 2000,
  };

  // Logique de gratuité (uniquement sur les annonces standard)
  if (paymentType === "announcement") {
    const keysToFetch = [
      "free_first_announcement",
      "promo_active",
      "promo_free_count",
      "promo_start_date",
      "promo_end_date",
    ];
    const { data: configs } = await supabase
      .from("app_config")
      .select("key, value")
      .in("key", keysToFetch);
    const cfg: Record<string, unknown> = {};
    for (const row of (configs ?? []) as Array<{ key: string; value: unknown }>) {
      cfg[row.key] = row.value;
    }

    const asBool = (v: unknown) => v === "true" || v === true;
    const asInt = (v: unknown) =>
      typeof v === "string" ? parseInt(v, 10) : Number(v);

    // 1. Première annonce gratuite (à vie, 1 fois par user)
    if (asBool(cfg["free_first_announcement"])) {
      const { count } = await supabase
        .from("payments")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId)
        .eq("type", "announcement")
        .eq("status", "completed");
      if ((count ?? 0) === 0) {
        console.log(`free: first announcement for user ${userId}`);
        return 0;
      }
    }

    // 2. Promo limitée dans le temps (N annonces gratuites par user)
    if (asBool(cfg["promo_active"])) {
      const now = new Date();
      const start = cfg["promo_start_date"]
        ? new Date(String(cfg["promo_start_date"]).replace(/"/g, ""))
        : null;
      const end = cfg["promo_end_date"]
        ? new Date(String(cfg["promo_end_date"]).replace(/"/g, ""))
        : null;
      const withinWindow =
        (!start || now >= start) && (!end || now <= end);
      const promoCount = asInt(cfg["promo_free_count"]);

      if (withinWindow && Number.isFinite(promoCount) && promoCount > 0) {
        // Compte les annonces gratuites déjà utilisées par cet user dans la fenêtre promo
        let q = supabase
          .from("payments")
          .select("id", { count: "exact", head: true })
          .eq("user_id", userId)
          .eq("type", "announcement")
          .eq("status", "completed")
          .eq("amount", 0);
        if (start) q = q.gte("paid_at", start.toISOString());
        if (end) q = q.lte("paid_at", end.toISOString());
        const { count: usedInPromo } = await q;
        if ((usedInPromo ?? 0) < promoCount) {
          console.log(
            `free: promo (${usedInPromo ?? 0}/${promoCount}) for user ${userId}`,
          );
          return 0;
        }
      }
    }
  }

  const key = keyByType[paymentType];
  const { data } = await supabase
    .from("app_config")
    .select("value")
    .eq("key", key)
    .maybeSingle();
  const raw = data?.value;
  const parsed = typeof raw === "string" ? parseInt(raw, 10) : Number(raw);
  if (Number.isFinite(parsed)) return parsed;
  return defaultByType[paymentType];
}

async function getUserIdFromRequest(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return null;
  const jwt = authHeader.slice(7);
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) return null;
  return data.user.id;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const userId = await getUserIdFromRequest(req);
  if (!userId) return jsonResponse({ error: "Unauthorized" }, 401);

  let body: InitiateRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const { announcement_id, payment_type, operator, phone_number } = body;
  if (!announcement_id || !payment_type) {
    return jsonResponse({ error: "Missing fields" }, 400);
  }
  if (!["announcement", "boost", "extension", "extra_announcement"].includes(payment_type)) {
    return jsonResponse({ error: "Invalid payment_type" }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { data: ann } = await supabase
    .from("announcements")
    .select("id, user_id")
    .eq("id", announcement_id)
    .single();
  if (!ann || ann.user_id !== userId) {
    return jsonResponse({ error: "Announcement not found" }, 404);
  }

  const amount = await resolveAmount(supabase, payment_type, userId);

  // Si amount > 0, operator + phone requis
  if (amount > 0) {
    if (!operator || !phone_number) {
      return jsonResponse({ error: "Operator and phone required for paid announcement" }, 400);
    }
    if (!["AIRTEL_MONEY", "MOOV_MONEY", "TEST"].includes(operator)) {
      return jsonResponse({ error: "Invalid operator" }, 400);
    }
  }
  const reference = generateReference(userId);
  const account = accountForOperator(operator);

  const { data: paymentRow, error: insertError } = await supabase
    .from("payments")
    .insert({
      user_id: userId,
      announcement_id,
      type: payment_type,
      amount,
      currency: "XAF",
      provider: amount > 0 ? "mypvit" : "free",
      reference,
      operator: amount > 0 ? operator : null,
      phone_number: amount > 0 ? phone_number : null,
      status: "pending",
      metadata: { initiated_at: new Date().toISOString() },
    })
    .select()
    .single();

  if (insertError || !paymentRow) {
    console.error("mypvit-initiate: DB insert failed", insertError);
    return jsonResponse({ error: "Failed to create payment" }, 500);
  }

  // Fast-path : amount = 0 → pas de paiement MyPvit, activation directe
  if (amount <= 0) {
    const now = new Date();
    const expiresAt = new Date(now);
    expiresAt.setDate(expiresAt.getDate() + 7);

    await supabase.from("payments").update({
      status: "completed",
      paid_at: now.toISOString(),
      payment_method: "free",
    }).eq("id", paymentRow.id);

    const annUpdate: Record<string, any> = {};
    if (payment_type === "extension") {
      const { data: currentAnn } = await supabase
        .from("announcements").select("expires_at").eq("id", announcement_id).single();
      const base = currentAnn?.expires_at
        ? new Date(Math.max(new Date(currentAnn.expires_at).getTime(), now.getTime()))
        : new Date(now);
      base.setDate(base.getDate() + 7);
      annUpdate.expires_at = base.toISOString();
    } else {
      annUpdate.status = "active";
      annUpdate.published_at = now.toISOString();
      annUpdate.expires_at = expiresAt.toISOString();
      if (payment_type === "boost") annUpdate.type = "boosted";
    }
    await supabase.from("announcements").update(annUpdate).eq("id", announcement_id);

    if (payment_type === "announcement" || payment_type === "boost") {
      try {
        await fetch(`${SUPABASE_URL}/functions/v1/match-alerts`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          },
          body: JSON.stringify({ announcement_id }),
        });
      } catch (e) {
        console.error("match-alerts trigger failed", e);
      }
    }

    return jsonResponse({
      payment_id: paymentRow.id,
      reference,
      amount: 0,
      currency: "XAF",
      mypvit_transaction_id: null,
      status: "completed",
      message: "Annonce publiée gratuitement.",
    }, 200);
  }

  try {
    let secret = await ensureSecret(supabase);
    let result = await callInitiatePayment(secret, {
      amount,
      reference,
      phone: phone_number,
      operator,
      account,
      productLabel: `GP Link - ${payment_type}`,
    });

    if (result.status === 401 || result.status === 403) {
      console.warn("mypvit-initiate: secret rejected, rotating");
      await supabase.from("mypvit_secrets").delete().eq("id", "current");
      await triggerRenewSecret();
      secret = await waitForSecret(supabase);
      result = await callInitiatePayment(secret, {
        amount, reference, phone: phone_number, operator, account,
        productLabel: `GP Link - ${payment_type}`,
      });
    }

    if (!result.ok) {
      await supabase
        .from("payments")
        .update({
          status: "failed",
          failed_at: new Date().toISOString(),
          metadata: { ...(paymentRow.metadata ?? {}), mypvit_error: result.body },
        })
        .eq("id", paymentRow.id);
      return jsonResponse({
        error: "MyPvit rejected the payment",
        details: result.body,
      }, 502);
    }

    const mypvitTxId = result.body?.reference_id ?? null;
    await supabase
      .from("payments")
      .update({
        mypvit_transaction_id: mypvitTxId,
        metadata: { ...(paymentRow.metadata ?? {}), mypvit_response: result.body },
      })
      .eq("id", paymentRow.id);

    return jsonResponse({
      payment_id: paymentRow.id,
      reference,
      amount,
      currency: "XAF",
      mypvit_transaction_id: mypvitTxId,
      status: "pending",
      message: "Confirmez le paiement sur votre telephone.",
    }, 200);
  } catch (e) {
    console.error("mypvit-initiate: unexpected error", e);
    await supabase
      .from("payments")
      .update({
        status: "failed",
        failed_at: new Date().toISOString(),
        metadata: { ...(paymentRow.metadata ?? {}), error: String(e) },
      })
      .eq("id", paymentRow.id);
    return jsonResponse({ error: "Payment initialization failed" }, 500);
  }
});
