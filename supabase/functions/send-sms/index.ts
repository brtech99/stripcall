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
    const twilioAccountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
    const twilioAuthToken = Deno.env.get("TWILIO_AUTH_TOKEN");

    if (!twilioAccountSid || !twilioAuthToken) {
      console.log("Twilio credentials not configured, skipping SMS");
      return new Response(
        JSON.stringify({
          success: true,
          skipped: true,
          reason: "Twilio not configured",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { problemId, message, type, senderName } = await req.json();
    console.log(
      `send-sms called: problemId=${problemId}, type=${type}, senderName=${senderName}, message=${message?.substring(0, 50)}`,
    );

    if (!problemId) {
      return new Response(JSON.stringify({ error: "Missing problemId" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get problem details including reporter_phone and crew info
    const { data: problem, error: problemError } = await adminClient
      .from("problem")
      .select(
        `
        id,
        strip,
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
      console.log("Problem not found:", problemId, problemError);
      return new Response(
        JSON.stringify({
          success: true,
          skipped: true,
          reason: "Problem not found",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    console.log(
      `Problem found: id=${problem.id}, reporter_phone=${problem.reporter_phone}, crew=${problem.crew}`,
    );

    // Get the Twilio "From" phone number based on crew type
    const crewTypeName = problem.crews?.crewtypes?.crewtype;
    const twilioFromPhone = crewTypeName
      ? CREW_TYPE_TO_PHONE[crewTypeName]
      : null;

    if (!twilioFromPhone) {
      console.log("No Twilio phone configured for crew type:", crewTypeName);
      return new Response(
        JSON.stringify({
          success: true,
          skipped: true,
          reason: "No Twilio phone for crew type",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const smsSent: string[] = [];

    // 1. Send SMS to reporter_phone if present (non-app user who texted in)
    if (problem.reporter_phone) {
      let smsBody: string;
      const displayName = senderName || "Crew";
      if (type === "on_my_way") {
        smsBody = `${displayName} is on the way to Strip ${problem.strip}`;
      } else {
        smsBody = `${displayName}: ${message || "New update on your report"}`;
      }

      try {
        await sendTwilioSms(
          twilioAccountSid,
          twilioAuthToken,
          twilioFromPhone,
          problem.reporter_phone,
          smsBody,
          adminClient,
        );
        smsSent.push(problem.reporter_phone);
        console.log("SMS sent to reporter:", problem.reporter_phone);
      } catch (smsError) {
        console.error("Failed to send SMS to reporter:", smsError);
      }
    }

    // 2. Send SMS to crew members who have is_sms_mode enabled
    // Query separately to avoid FK ambiguity
    const { data: crewMembers, error: crewError } = await adminClient
      .from("crewmembers")
      .select("crewmember")
      .eq("crew", problem.crew);

    if (!crewError && crewMembers && crewMembers.length > 0) {
      // Get user data for these crew members
      const memberIds = crewMembers.map((cm: any) => cm.crewmember);
      const { data: users } = await adminClient
        .from("users")
        .select("supabase_id, phonenbr, is_sms_mode, firstname, lastname")
        .in("supabase_id", memberIds);

      for (const user of users || []) {
        if (user?.is_sms_mode && user?.phonenbr) {
          let smsBody: string;
          const displayName = senderName || "Crew";
          if (type === "on_my_way") {
            smsBody = `[Strip ${problem.strip}] ${displayName} is on the way`;
          } else {
            // App crew member sending message - just show username: message (no +n)
            smsBody = `${displayName}: ${message}`;
          }

          try {
            await sendTwilioSms(
              twilioAccountSid,
              twilioAuthToken,
              twilioFromPhone,
              user.phonenbr,
              smsBody,
              adminClient,
            );
            smsSent.push(user.phonenbr);
            console.log("SMS sent to crew member:", user.phonenbr);
          } catch (smsError) {
            console.error(
              "Failed to send SMS to crew member:",
              user.phonenbr,
              smsError,
            );
          }
        }
      }
    }

    return new Response(JSON.stringify({ success: true, smsSent }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("send-sms error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// Check if phone is a simulator phone (2025551001-2025551005)
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
  // Check if this is a simulator phone number
  if (isSimulatorPhone(to) && adminClient) {
    const normalizedTo = to.replace(/\D/g, "").replace(/^1/, "");
    console.log("Routing to SMS simulator:", normalizedTo);

    // Insert into sms_simulator table as inbound (message coming TO the simulated phone)
    await adminClient.from("sms_simulator").insert({
      phone: normalizedTo,
      direction: "inbound",
      twilio_number: from,
      message: body,
    });

    return { sid: "SIMULATOR", to: normalizedTo };
  }

  // Real Twilio send
  const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: "Basic " + btoa(`${accountSid}:${authToken}`),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      To: to,
      From: from,
      Body: body,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Twilio error: ${response.status} - ${errorText}`);
  }

  return await response.json();
}

async function getOrAssignSlot(
  adminClient: any,
  crewId: number,
  phone: string,
  problemId: number,
): Promise<number> {
  // Check if slot already exists for this problem
  const { data: existingSlot } = await adminClient
    .from("sms_reply_slots")
    .select("slot")
    .eq("crew_id", crewId)
    .eq("problem_id", problemId)
    .maybeSingle();

  if (existingSlot) {
    return existingSlot.slot;
  }

  // Get or initialize the slot counter for this crew
  const { data: counter } = await adminClient
    .from("sms_crew_slot_counter")
    .select("next_slot")
    .eq("crew_id", crewId)
    .maybeSingle();

  let nextSlot = counter?.next_slot || 1;

  // Upsert the slot assignment (overwriting if slot already used)
  await adminClient.from("sms_reply_slots").upsert(
    {
      crew_id: crewId,
      slot: nextSlot,
      phone: phone,
      problem_id: problemId,
      assigned_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    },
    { onConflict: "crew_id,slot" },
  );

  // Update the counter (rotate 1-4)
  const newNextSlot = (nextSlot % 4) + 1;
  await adminClient
    .from("sms_crew_slot_counter")
    .upsert(
      { crew_id: crewId, next_slot: newNextSlot },
      { onConflict: "crew_id" },
    );

  return nextSlot;
}
