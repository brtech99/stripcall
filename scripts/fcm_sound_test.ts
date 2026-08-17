// One-off diagnostic: send labeled FCM push variants to one iOS device token
// to isolate why aps.sound="default" isn't playing. Run:
//   DEVICE_TOKEN=... deno run -A scripts/fcm_sound_test.ts
// Reuses the exact RS256/JWT signing from supabase/functions/send-fcm-notification.

const saPath = Deno.env.get("SERVICE_ACCOUNT") ??
  new URL("../serviceAccountKey.json", import.meta.url).pathname;
const serviceAccount = JSON.parse(await Deno.readTextFile(saPath));
const projectId = serviceAccount.project_id;
const token = Deno.env.get("DEVICE_TOKEN");
if (!token) throw new Error("DEVICE_TOKEN env var required");

async function signRS256(input: string, privateKey: string): Promise<string> {
  const keyData = privateKey
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const keyBuffer = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBuffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(input),
  );
  return btoa(String.fromCharCode(...new Uint8Array(sig)));
}

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT", kid: serviceAccount.private_key_id };
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };
  const enc = (o: unknown) => btoa(JSON.stringify(o));
  const signingInput = `${enc(header)}.${enc(payload)}`;
  const signature = await signRS256(signingInput, serviceAccount.private_key);
  const jwt = `${signingInput}.${signature}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error("token: " + res.status + " " + (await res.text()));
  return (await res.json()).access_token;
}

async function send(accessToken: string, label: string, message: Record<string, unknown>) {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message: { token, ...message } }),
    },
  );
  const body = await res.json();
  console.log(`${label}: ${res.status} ${res.ok ? "OK " + (body.name ?? "") : JSON.stringify(body)}`);
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// Variant A — EXACT current app payload (top-level notification + apns aps).
const A = {
  notification: { title: "TEST A baseline", body: "exact current payload" },
  data: { type: "test" },
  apns: {
    headers: { "apns-priority": "10", "apns-push-type": "alert" },
    payload: {
      aps: { alert: { title: "TEST A baseline", body: "exact current payload" }, sound: "default", badge: 1 },
      type: "test",
    },
  },
};

// Variant B — APNs-only (NO top-level notification block).
const B = {
  apns: {
    headers: { "apns-priority": "10", "apns-push-type": "alert" },
    payload: {
      aps: { alert: { title: "TEST B apns-only", body: "no top-level notification" }, sound: "default", badge: 1 },
    },
  },
};

// Variant C — APNs-only + Time-Sensitive interruption level.
const C = {
  apns: {
    headers: { "apns-priority": "10", "apns-push-type": "alert" },
    payload: {
      aps: {
        alert: { title: "TEST C time-sensitive", body: "interruption-level time-sensitive" },
        sound: "default",
        badge: 1,
        "interruption-level": "time-sensitive",
      },
    },
  },
};

// Variant D — minimal aps, alert + sound only.
const D = {
  apns: {
    headers: { "apns-priority": "10", "apns-push-type": "alert" },
    payload: {
      aps: { alert: { title: "TEST D minimal", body: "alert + sound default only" }, sound: "default" },
    },
  },
};

const accessToken = await getAccessToken();
console.log("Sending to token:", token.slice(0, 16) + "... (lock phone, do NOT look at it)\n");
const only = Deno.env.get("ONLY");
const variants = ([["A", A], ["B", B], ["C", C], ["D", D]] as const)
  .filter(([label]) => !only || label === only);
for (const [label, msg] of variants) {
  await send(accessToken, "TEST " + label, msg);
  await sleep(9000);
}
console.log("\nDone. Which TEST letters made a SOUND?");
