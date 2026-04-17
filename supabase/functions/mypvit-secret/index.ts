// Edge Function: mypvit-secret
// Receives the MyPvit authentication secret asynchronously after /renew-secret is called.
// Endpoint is public (no JWT, no custom token) because MyPvit does not send auth headers
// and the secret itself is the sensitive payload we're receiving.
// Deploy with: supabase functions deploy mypvit-secret --no-verify-jwt

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function extractSecret(raw: string, parsed: Record<string, unknown> | null): string | null {
  if (parsed && typeof parsed === "object") {
    for (const key of ["secret", "secretKey", "secret_key", "key", "data"]) {
      const v = parsed[key];
      if (typeof v === "string" && v.length > 8) return v;
    }
  }
  const trimmed = raw.trim();
  if (trimmed.length > 8 && !trimmed.startsWith("{") && !trimmed.startsWith("[")) {
    return trimmed;
  }
  return null;
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

  const raw = await req.text();
  let parsed: Record<string, unknown> | null = null;
  try {
    parsed = JSON.parse(raw);
  } catch {
    parsed = null;
  }

  const secret = extractSecret(raw, parsed);
  if (!secret) {
    console.warn("mypvit-secret: no secret found in payload", { raw: raw.slice(0, 200) });
    return jsonResponse({ responseCode: 400, message: "Secret not found" }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const expiresAt = new Date(Date.now() + 50 * 60 * 1000).toISOString();
  const { error } = await supabase
    .from("mypvit_secrets")
    .upsert({
      id: "current",
      secret,
      received_at: new Date().toISOString(),
      expires_at: expiresAt,
    });

  if (error) {
    console.error("mypvit-secret: DB upsert failed", error);
    return jsonResponse({ responseCode: 500, message: "DB error" }, 500);
  }

  console.log(`mypvit-secret: cached secret, expires at ${expiresAt}`);
  return jsonResponse({ responseCode: 200, message: "Secret received" }, 200);
});
