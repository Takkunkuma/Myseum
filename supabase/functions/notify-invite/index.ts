// notify-invite — sends an APNs push when a row is inserted into event_shares.
// Triggered by a Supabase Database Webhook (event_shares · INSERT).
//
// Deploy:  supabase functions deploy notify-invite --no-verify-jwt
// Secrets: APNS_KEY_ID, APNS_TEAM_ID, APNS_TOPIC (= com.myseum.app),
//          APNS_PRIVATE_KEY (contents of the .p8), APNS_HOST
//          (api.sandbox.push.apple.com for dev builds, api.push.apple.com for App Store/TestFlight).
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const env = (k: string) => Deno.env.get(k) ?? "";
const APNS_KEY_ID = env("APNS_KEY_ID");
const APNS_TEAM_ID = env("APNS_TEAM_ID");
const APNS_TOPIC = env("APNS_TOPIC");
const APNS_HOST = env("APNS_HOST") || "api.sandbox.push.apple.com";
const APNS_PRIVATE_KEY = env("APNS_PRIVATE_KEY");

function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bin = atob(body);
  const buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  return buf.buffer;
}

async function apnsJWT(): Promise<string> {
  const header = { alg: "ES256", kid: APNS_KEY_ID };
  const claims = { iss: APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(APNS_PRIVATE_KEY),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64url(sig)}`;
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record ?? payload; // DB webhook nests the new row under `record`
    const inviteeId: string | undefined = record?.invitee;
    const ownerId: string | undefined = record?.owner;
    const title: string = record?.title ?? "an event";
    if (!inviteeId) return new Response("no invitee", { status: 200 });

    const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));

    const { data: tokens } = await supabase
      .from("device_tokens").select("token").eq("user_id", inviteeId);
    if (!tokens?.length) return new Response("no device tokens", { status: 200 });

    let ownerName = "A friend";
    if (ownerId) {
      const { data: owner } = await supabase
        .from("profiles").select("username").eq("id", ownerId).single();
      if (owner?.username) ownerName = owner.username;
    }

    const jwt = await apnsJWT();
    const body = JSON.stringify({
      aps: {
        alert: { title: "New event invite", body: `${ownerName} invited you to “${title}”` },
        sound: "default",
        "interruption-level": "active",
      },
    });

    const results: unknown[] = [];
    for (const { token } of tokens) {
      const res = await fetch(`https://${APNS_HOST}/3/device/${token}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": APNS_TOPIC,
          "apns-push-type": "alert",
          "content-type": "application/json",
        },
        body,
      });
      // Clean up tokens APNs says are dead.
      if (res.status === 410 || res.status === 400) {
        await supabase.from("device_tokens").delete().eq("token", token);
      }
      results.push({ token: token.slice(0, 8), status: res.status });
    }

    return new Response(JSON.stringify({ ok: true, results }), {
      headers: { "content-type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
