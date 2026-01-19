import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { encode as base64Encode } from "https://deno.land/std@0.168.0/encoding/base64.ts";

// Twilio phone -> crew type mapping
const PHONE_TO_CREW_TYPE: Record<string, string> = {
  "+17542276679": "Armorer",
  "+13127577223": "Medical",
  "+16504803067": "Natloff",
};

// Strip parsing patterns
const STRIP_PATTERNS = [
  /strip\s*#?\s*(\d+|[A-Z]\d+|Finals)/i, // "strip 5", "strip #5", "strip A3", "strip Finals"
  /\b([A-Z]\d+)\s*strip/i, // "A3 strip"
  /\bL(\d+)\b/i, // "L4" -> "4"
  /\b([A-Z]\d+)\b/, // "A3", "B2" standalone
  /\bstrip\s+(\w+)/i, // "strip finals"
];

serve(async (req) => {
  try {
    // Verify Twilio signature
    const isValid = await verifyTwilioSignature(req);
    if (!isValid) {
      console.error("Invalid Twilio signature");
      return new Response("Forbidden", { status: 403 });
    }

    // Parse Twilio webhook (application/x-www-form-urlencoded)
    const formData = await req.formData();
    const from = formData.get("From") as string;
    const to = formData.get("To") as string;
    const body = ((formData.get("Body") as string) || "").trim();

    console.log(`SMS received: From=${from}, To=${to}, Body=${body}`);

    // Create Supabase client with service role
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Determine target crew type from Twilio number
    const crewTypeName = PHONE_TO_CREW_TYPE[to];
    if (!crewTypeName) {
      console.error(`Unknown Twilio number: ${to}`);
      return twimlResponse("Sorry, this number is not configured.");
    }

    // Find the crew for the current active event
    const crew = await findCrewByType(supabase, crewTypeName);
    if (!crew) {
      console.error(`No crew found for type: ${crewTypeName}`);
      return twimlResponse("No active crew found for this number.");
    }

    // Check if sender is a crew member (has profile with matching phone)
    const normalizedPhone = normalizePhone(from);
    const { data: crewMemberUser } = await supabase
      .from("users")
      .select("supabase_id, firstname, lastname, phonenbr")
      .or(`phonenbr.eq.${normalizedPhone},phonenbr.eq.${from}`)
      .limit(1)
      .single();

    let isCrewMember = false;
    if (crewMemberUser) {
      const { data: membership } = await supabase
        .from("crewmembers")
        .select("id")
        .eq("crewmember", crewMemberUser.supabase_id)
        .eq("crew", crew.id)
        .single();
      isCrewMember = !!membership;
    }

    // Parse +N prefix for routing
    const prefixMatch = body.match(/^\+(\d)\s*(.*)/);
    const replySlot = prefixMatch ? parseInt(prefixMatch[1]) : null;
    const messageBody = prefixMatch ? prefixMatch[2].trim() : body;

    if (isCrewMember && crewMemberUser) {
      // CREW MEMBER SMS
      if (replySlot) {
        // Route to specific problem via reply slot
        return await handleCrewMemberReply(
          supabase,
          crew.id,
          crewMemberUser,
          replySlot,
          messageBody,
          from,
        );
      } else {
        // Broadcast to crew_messages
        return await handleCrewBroadcast(
          supabase,
          crew.id,
          crewMemberUser,
          messageBody,
        );
      }
    } else {
      // REFEREE/EXTERNAL SMS
      return await handleRefereeMessage(
        supabase,
        crew.id,
        crew.event,
        from,
        messageBody,
      );
    }
  } catch (error) {
    console.error("Error processing SMS:", error);
    return twimlResponse("An error occurred. Please try again.");
  }
});

async function verifyTwilioSignature(req: Request): Promise<boolean> {
  const authToken = Deno.env.get("TWILIO_AUTH_TOKEN");
  if (!authToken) {
    console.error("TWILIO_AUTH_TOKEN not set");
    return false;
  }

  const signature = req.headers.get("X-Twilio-Signature");
  if (!signature) {
    console.error("No X-Twilio-Signature header");
    return false;
  }

  // Clone request to read body without consuming it
  const clonedReq = req.clone();
  const formData = await clonedReq.formData();

  // Build the validation URL - use the actual Twilio webhook URL, not the internal URL
  // Twilio signs with the URL you configured in their console
  const webhookUrl =
    "https://wpytorahphbnzgikowgz.supabase.co/functions/v1/receive-sms";

  // Sort form params and concatenate
  const params: [string, string][] = [];
  formData.forEach((value, key) => {
    params.push([key, value as string]);
  });
  params.sort((a, b) => a[0].localeCompare(b[0]));

  const paramString = params.map(([k, v]) => `${k}${v}`).join("");
  const dataToSign = webhookUrl + paramString;

  // HMAC-SHA1
  const encoder = new TextEncoder();
  const keyData = encoder.encode(authToken);
  const messageData = encoder.encode(dataToSign);

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );

  const signatureBuffer = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    messageData,
  );
  const computedSignature = base64Encode(new Uint8Array(signatureBuffer));

  return computedSignature === signature;
}

async function findCrewByType(supabase: any, crewTypeName: string) {
  // Get crew type ID
  const { data: crewType } = await supabase
    .from("crewtypes")
    .select("id")
    .eq("crewtype", crewTypeName)
    .single();

  if (!crewType) {
    console.error(`Crew type not found: ${crewTypeName}`);
    return null;
  }

  // Find the most recent crew of this type (assumes current event)
  const { data: crew } = await supabase
    .from("crews")
    .select("id, event")
    .eq("crew_type", crewType.id)
    .order("id", { ascending: false })
    .limit(1)
    .single();

  return crew;
}

async function handleRefereeMessage(
  supabase: any,
  crewId: number,
  eventId: number,
  phone: string,
  message: string,
) {
  // Try to find the user by phone number in the users table first
  const normalizedPhone = normalizePhone(phone);
  const { data: userByPhone } = await supabase
    .from("users")
    .select("firstname, lastname, phonenbr")
    .or(`phonenbr.eq.${normalizedPhone},phonenbr.eq.${phone}`)
    .limit(1)
    .single();

  let reporterName: string;
  if (userByPhone) {
    // Found user in database - use their name
    reporterName =
      `${userByPhone.firstname || ""} ${userByPhone.lastname || ""}`.trim() ||
      normalizedPhone;
  } else {
    // Not found in users table - try sms_reporters table
    const { data: reporter } = await supabase
      .from("sms_reporters")
      .select("name")
      .eq("phone", phone)
      .single();

    // Use reporter name, or just the phone number (digits only, no formatting)
    reporterName = reporter?.name || normalizedPhone;
  }

  // Check for existing active problem from this phone for this crew
  const { data: existingProblem } = await supabase
    .from("problem")
    .select("id, strip")
    .eq("reporter_phone", phone)
    .eq("crew", crewId)
    .is("enddatetime", null)
    .order("startdatetime", { ascending: false })
    .limit(1)
    .single();

  if (existingProblem) {
    // Add message to existing problem
    // Format: "username: message" to match app message format
    await supabase.from("messages").insert({
      problem: existingProblem.id,
      crew: crewId,
      author: null, // SMS messages have no app user author
      message: `${reporterName}: ${message}`,
      include_reporter: true,
      created_at: new Date().toISOString(),
    });

    console.log(`Added message to existing problem ${existingProblem.id}`);
    return twimlResponse(
      `Message added to your report for Strip ${existingProblem.strip}. ` +
        `A crew member will respond shortly.`,
    );
  }

  // Create new problem
  const strip = parseStrip(message) || "Unknown";

  // Get SMS symptom ID
  const { data: smsSymptom } = await supabase
    .from("symptom")
    .select("id, symptomclass!inner(crewType)")
    .eq("symptomstring", "SMS Report - Needs Triage")
    .limit(1)
    .single();

  if (!smsSymptom) {
    console.error("SMS symptom not found - migration may not have run");
    return twimlResponse("System configuration error. Please contact support.");
  }

  // Create the problem - use a placeholder originator since SMS users don't have accounts
  // We'll use the reporter_phone to track them
  const { data: newProblem, error: problemError } = await supabase
    .from("problem")
    .insert({
      event: eventId,
      crew: crewId,
      originator: null, // No app user - tracked via reporter_phone
      strip: strip,
      symptom: smsSymptom.id,
      startdatetime: new Date().toISOString(),
      reporter_phone: phone,
    })
    .select("id")
    .single();

  if (problemError) {
    console.error("Error creating problem:", problemError);
    return twimlResponse("Error creating report. Please try again.");
  }

  // Assign reply slot
  const slot = await assignReplySlot(supabase, crewId, phone, newProblem.id);

  // Add initial message - format: "username: message" to match app message format
  await supabase.from("messages").insert({
    problem: newProblem.id,
    crew: crewId,
    author: null,
    message: `${reporterName}: ${message}`,
    include_reporter: true,
    created_at: new Date().toISOString(),
  });

  console.log(
    `Created new problem ${newProblem.id} for strip ${strip}, slot +${slot}`,
  );

  return twimlResponse(
    `Problem reported for Strip ${strip}. ` +
      `Reply with +${slot} to add updates. ` +
      `A crew member will respond shortly.`,
  );
}

async function handleCrewMemberReply(
  supabase: any,
  crewId: number,
  user: any,
  slot: number,
  message: string,
  senderPhone: string,
) {
  // Find problem by reply slot
  const { data: slotData } = await supabase
    .from("sms_reply_slots")
    .select("problem_id, phone")
    .eq("crew_id", crewId)
    .eq("slot", slot)
    .single();

  if (!slotData?.problem_id) {
    return twimlResponse(`No active problem in slot +${slot}.`);
  }

  const senderName =
    `${user.firstname} ${user.lastname}`.trim() || "Crew Member";

  // Add message to problem (include_reporter so SMS sender sees it)
  await supabase.from("messages").insert({
    problem: slotData.problem_id,
    crew: crewId,
    author: user.supabase_id,
    message: message,
    include_reporter: true,
    created_at: new Date().toISOString(),
  });

  // Send SMS to the reporter
  await sendSmsToReporter(supabase, slotData.problem_id, senderName, message);

  console.log(
    `Crew member ${senderName} replied to problem ${slotData.problem_id} via slot +${slot}`,
  );

  return twimlResponse(
    `Message sent to reporter for problem in slot +${slot}.`,
  );
}

async function handleCrewBroadcast(
  supabase: any,
  crewId: number,
  user: any,
  message: string,
) {
  const senderName =
    `${user.firstname} ${user.lastname}`.trim() || "Crew Member";

  await supabase.from("crew_messages").insert({
    crew: crewId,
    author: user.supabase_id,
    message: `[SMS from ${senderName}] ${message}`,
    created_at: new Date().toISOString(),
  });

  console.log(`Crew member ${senderName} broadcast message to crew ${crewId}`);

  return twimlResponse("Message broadcast to crew.");
}

async function assignReplySlot(
  supabase: any,
  crewId: number,
  phone: string,
  problemId: number,
): Promise<number> {
  // Clean up expired slots first
  await supabase
    .from("sms_reply_slots")
    .delete()
    .lt("expires_at", new Date().toISOString());

  // Try each slot 1-4
  for (let slot = 1; slot <= 4; slot++) {
    const { error } = await supabase.from("sms_reply_slots").upsert(
      {
        crew_id: crewId,
        slot: slot,
        phone: phone,
        problem_id: problemId,
        assigned_at: new Date().toISOString(),
        expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      },
      {
        onConflict: "crew_id,slot",
      },
    );

    if (!error) {
      return slot;
    }
  }

  // All slots in use - reuse the oldest one
  const { data: oldest } = await supabase
    .from("sms_reply_slots")
    .select("slot")
    .eq("crew_id", crewId)
    .order("assigned_at", { ascending: true })
    .limit(1)
    .single();

  const slot = oldest?.slot || 1;

  await supabase
    .from("sms_reply_slots")
    .update({
      phone: phone,
      problem_id: problemId,
      assigned_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    })
    .eq("crew_id", crewId)
    .eq("slot", slot);

  return slot;
}

async function sendSmsToReporter(
  supabase: any,
  problemId: number,
  senderName: string,
  message: string,
) {
  // Get problem details
  const { data: problem } = await supabase
    .from("problem")
    .select("reporter_phone, strip, crew(crew_type(crewtype))")
    .eq("id", problemId)
    .single();

  if (!problem?.reporter_phone) {
    return;
  }

  const crewTypeName = problem.crew?.crew_type?.crewtype;
  const CREW_TYPE_TO_PHONE: Record<string, string> = {
    Armorer: "+17542276679",
    Medical: "+13127577223",
    Natloff: "+16504803067",
  };

  const fromPhone = CREW_TYPE_TO_PHONE[crewTypeName];
  if (!fromPhone) {
    console.error(`No phone mapping for crew type: ${crewTypeName}`);
    return;
  }

  const smsBody = `[Strip ${problem.strip}] ${senderName}: ${message}`;

  await sendTwilioSms(fromPhone, problem.reporter_phone, smsBody);
}

async function sendTwilioSms(from: string, to: string, body: string) {
  const accountSid = Deno.env.get("TWILIO_ACCOUNT_SID")!;
  const authToken = Deno.env.get("TWILIO_AUTH_TOKEN")!;

  try {
    const response = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
      {
        method: "POST",
        headers: {
          Authorization: `Basic ${btoa(`${accountSid}:${authToken}`)}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({ From: from, To: to, Body: body }),
      },
    );

    if (response.ok) {
      const data = await response.json();
      console.log(`SMS sent: ${data.sid}`);
    } else {
      const error = await response.text();
      console.error("Twilio error:", error);
    }
  } catch (err) {
    console.error("Error sending SMS:", err);
  }
}

function parseStrip(message: string): string | null {
  for (const pattern of STRIP_PATTERNS) {
    const match = message.match(pattern);
    if (match) {
      let strip = match[1];
      // Normalize "L4" to just "4"
      if (/^L\d+$/i.test(strip)) {
        strip = strip.substring(1);
      }
      return strip.toUpperCase();
    }
  }
  return null;
}

function normalizePhone(phone: string): string {
  // Remove all non-digits and take last 10
  return phone.replace(/\D/g, "").slice(-10);
}

function formatPhoneForDisplay(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  if (digits.length === 10) {
    return `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`;
  }
  if (digits.length === 11 && digits[0] === "1") {
    return `(${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(7)}`;
  }
  return phone;
}

function twimlResponse(_message?: string): Response {
  // Return empty TwiML response - no auto-reply to SMS
  // The original system didn't send confirmation messages back to the sender
  const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response></Response>`;

  return new Response(twiml, {
    headers: { "Content-Type": "text/xml" },
  });
}
