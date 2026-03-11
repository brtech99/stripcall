import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Map crew type to Twilio phone number
const CREW_TYPE_TO_PHONE: Record<string, string> = {
  Armorer: "+17542276679",
  Medical: "+13127577223",
  Natloff: "+16504803067",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const adminClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { problemId, userId } = await req.json();
    console.log(`go-on-my-way: problemId=${problemId}, userId=${userId}`);

    if (!problemId || !userId) {
      return new Response(
        JSON.stringify({ error: "Missing problemId or userId" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 1. Validate user exists and get name
    const { data: user, error: userError } = await adminClient
      .from("users")
      .select("firstname, lastname")
      .eq("supabase_id", userId)
      .single();

    if (userError || !user) {
      console.error("User not found:", userId, userError);
      return new Response(JSON.stringify({ error: "User not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const responderName = `${user.firstname} ${user.lastname}`;

    // 2. Get problem details
    const { data: problem, error: problemError } = await adminClient
      .from("problem")
      .select(
        `
        id,
        strip,
        originator,
        reporter_phone,
        crew,
        crews:crew (
          id,
          crew_type,
          crewtypes:crew_type (
            id,
            crewtype
          )
        )
      `,
      )
      .eq("id", problemId)
      .single();

    if (problemError || !problem) {
      console.error("Problem not found:", problemId, problemError);
      return new Response(JSON.stringify({ error: "Problem not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Insert responder
    const { error: insertError } = await adminClient
      .from("responders")
      .insert({
        problem: problemId,
        user_id: userId,
        responded_at: new Date().toISOString(),
      });

    if (insertError) {
      if (
        insertError.message?.includes("duplicate key") ||
        insertError.message?.includes("UNIQUE") ||
        insertError.code === "23505"
      ) {
        console.log("User already responding:", userId);
        return new Response(
          JSON.stringify({ success: true, message: "Already en route" }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
      console.error("Insert responder failed:", insertError);
      return new Response(
        JSON.stringify({ error: "Failed to record response" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    console.log(`Responder recorded: ${responderName} for problem ${problemId}`);

    // 4. Insert crew message (fire and forget)
    adminClient
      .from("crew_messages")
      .insert({
        crew: problem.crew,
        author: userId,
        message: `${responderName} is on the way`,
      })
      .then(({ error }) => {
        if (error) console.error("Crew message insert failed:", error);
      });

    // 5. Send FCM notifications (fire and forget)
    sendFCMNotifications(
      adminClient,
      problem.crew,
      userId,
      responderName,
      problem.strip,
      problemId,
    ).catch((e) => console.error("FCM notification error:", e));

    // 6. Send SMS (fire and forget)
    sendSMSNotifications(
      adminClient,
      problem,
      responderName,
    ).catch((e) => console.error("SMS notification error:", e));

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("go-on-my-way error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// ─── FCM Notifications ──────────────────────────────────────────────

async function sendFCMNotifications(
  adminClient: any,
  crewId: number,
  senderId: string,
  responderName: string,
  strip: string,
  problemId: number,
) {
  const fcmServiceAccountKey = Deno.env.get("FCM_SERVICE_ACCOUNT_KEY");
  if (!fcmServiceAccountKey) {
    console.log("FCM service account key not configured, skipping notifications");
    return;
  }

  const serviceAccount = JSON.parse(fcmServiceAccountKey);
  const projectId = serviceAccount.project_id;

  // Get crew members (excluding sender)
  const { data: crewMembers } = await adminClient
    .from("crewmembers")
    .select("crewmember")
    .eq("crew", crewId);

  if (!crewMembers || crewMembers.length === 0) return;

  // Include superusers
  const { data: superusers } = await adminClient
    .from("users")
    .select("supabase_id")
    .eq("superuser", true);

  const userIds = new Set(
    crewMembers.map((m: any) => m.crewmember as string),
  );
  for (const su of superusers || []) {
    userIds.add(su.supabase_id);
  }
  // Remove the sender
  userIds.delete(senderId);

  if (userIds.size === 0) return;

  // Get device tokens
  const { data: deviceTokens } = await adminClient
    .from("device_tokens")
    .select("device_token")
    .in("user_id", Array.from(userIds));

  if (!deviceTokens || deviceTokens.length === 0) return;

  const jwt = await getGoogleAccessToken(serviceAccount);

  const title = `${responderName} responding to ${strip}`;
  const body = `${responderName} responding to ${strip}`;
  const data = {
    type: "problem_response",
    problemId: problemId.toString(),
    crewId: crewId.toString(),
    strip: strip,
  };

  await Promise.allSettled(
    deviceTokens.map((dt: any) =>
      sendFCMMessage(projectId, jwt, dt.device_token, title, body, data),
    ),
  );

  console.log(
    `FCM notifications sent to ${deviceTokens.length} devices`,
  );
}

async function sendFCMMessage(
  projectId: string,
  jwt: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
) {
  const fcmPayload = {
    message: {
      token,
      notification: { title, body },
      data,
      android: {
        priority: "high",
        notification: { sound: "default" },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: { title, body },
            sound: "default",
            badge: 1,
          },
        },
      },
      webpush: {
        notification: {
          icon: "https://stripcall.us/app/icons/Icon-192.png",
          badge: "https://stripcall.us/app/icons/Icon-192.png",
        },
      },
    },
  };

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${jwt}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(fcmPayload),
    },
  );

  if (!response.ok) {
    const errorData = await response.json();
    console.error(`FCM error for ${token.substring(0, 20)}...:`, errorData);
  }
}

// ─── SMS Notifications ──────────────────────────────────────────────

async function sendSMSNotifications(
  adminClient: any,
  problem: any,
  responderName: string,
) {
  const twilioAccountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
  const twilioAuthToken = Deno.env.get("TWILIO_AUTH_TOKEN");

  if (!twilioAccountSid || !twilioAuthToken) {
    console.log("Twilio not configured, skipping SMS");
    return;
  }

  const crewTypeName = problem.crews?.crewtypes?.crewtype;
  const twilioFromPhone = crewTypeName
    ? CREW_TYPE_TO_PHONE[crewTypeName]
    : null;

  if (!twilioFromPhone) {
    console.log("No Twilio phone for crew type:", crewTypeName);
    return;
  }

  const smsBody = `${responderName} is on the way to Strip ${problem.strip}`;

  // Send to reporter if they have a phone
  if (problem.reporter_phone) {
    try {
      await sendTwilioSms(
        twilioAccountSid,
        twilioAuthToken,
        twilioFromPhone,
        problem.reporter_phone,
        smsBody,
        adminClient,
      );
      console.log("SMS sent to reporter:", problem.reporter_phone);
    } catch (e) {
      console.error("SMS to reporter failed:", e);
    }
  }

  // Send to SMS-mode crew members
  const { data: crewMembers } = await adminClient
    .from("crewmembers")
    .select("crewmember")
    .eq("crew", problem.crew);

  if (crewMembers && crewMembers.length > 0) {
    const memberIds = crewMembers.map((cm: any) => cm.crewmember);
    const { data: users } = await adminClient
      .from("users")
      .select("supabase_id, phonenbr, is_sms_mode")
      .in("supabase_id", memberIds);

    for (const u of users || []) {
      if (u?.is_sms_mode && u?.phonenbr) {
        try {
          await sendTwilioSms(
            twilioAccountSid,
            twilioAuthToken,
            twilioFromPhone,
            u.phonenbr,
            smsBody,
            adminClient,
          );
          console.log("SMS sent to crew member:", u.phonenbr);
        } catch (e) {
          console.error("SMS to crew member failed:", u.phonenbr, e);
        }
      }
    }
  }
}

function isSimulatorPhone(phone: string): boolean {
  const normalized = phone.replace(/\D/g, "").replace(/^1/, "");
  return /^202555100[1-5]$/.test(normalized);
}

async function sendTwilioSms(
  accountSid: string,
  authToken: string,
  from: string,
  to: string,
  body: string,
  adminClient?: any,
) {
  if (isSimulatorPhone(to) && adminClient) {
    const normalizedTo = to.replace(/\D/g, "").replace(/^1/, "");
    console.log("Routing to SMS simulator:", normalizedTo);
    await adminClient.from("sms_simulator").insert({
      phone: normalizedTo,
      direction: "inbound",
      twilio_number: from,
      message: body,
    });
    return;
  }

  const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: "Basic " + btoa(`${accountSid}:${authToken}`),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({ To: to, From: from, Body: body }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Twilio error: ${response.status} - ${errorText}`);
  }
}

// ─── Google OAuth for FCM ───────────────────────────────────────────

let cachedJWT: { token: string; expiresAt: number } | null = null;

async function getGoogleAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  if (cachedJWT && cachedJWT.expiresAt > now + 300) {
    return cachedJWT.token;
  }

  const header = {
    alg: "RS256",
    typ: "JWT",
    kid: serviceAccount.private_key_id,
  };

  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const encodedHeader = btoa(JSON.stringify(header));
  const encodedPayload = btoa(JSON.stringify(payload));
  const signatureInput = `${encodedHeader}.${encodedPayload}`;
  const signature = await signRS256(signatureInput, serviceAccount.private_key);
  const jwt = `${signatureInput}.${signature}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Google OAuth error: ${response.status} ${errorText}`);
  }

  const data = await response.json();
  cachedJWT = { token: data.access_token, expiresAt: now + 3600 };
  return data.access_token;
}

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

  const encoder = new TextEncoder();
  const data = encoder.encode(input);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    data,
  );

  return btoa(String.fromCharCode(...new Uint8Array(signature)));
}
