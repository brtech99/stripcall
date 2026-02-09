import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Map Twilio phone to crew type name
const PHONE_TO_CREW_TYPE: Record<string, string> = {
  "+17542276679": "Armorer",
  "+13127577223": "Medical",
  "+16504803067": "Natloff",
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

    // Parse Twilio webhook form data
    const formData = await req.formData();
    const from = formData.get("From") as string; // Sender's phone
    const to = formData.get("To") as string; // Our Twilio number
    const body = ((formData.get("Body") as string) || "").trim();

    console.log(`SMS received: From=${from}, To=${to}, Body=${body}`);

    if (!from || !to || !body) {
      return twimlResponse("Invalid message received");
    }

    // Normalize phone numbers (remove +1 prefix variations)
    const normalizedFrom = normalizePhone(from);
    const normalizedTo = normalizePhone(to);

    console.log(
      `Normalized phones: from=${normalizedFrom}, to=${normalizedTo}`,
    );

    // Determine crew type from the "To" number
    const crewTypeName =
      PHONE_TO_CREW_TYPE[to] || PHONE_TO_CREW_TYPE["+1" + normalizedTo];
    console.log(`Crew type lookup: to=${to}, crewTypeName=${crewTypeName}`);
    if (!crewTypeName) {
      console.log("Unknown Twilio number:", to);
      return twimlResponse("Unknown crew number");
    }

    // Find the crew for this crew type (most recent/active)
    const crew = await findCrewByType(adminClient, crewTypeName);
    if (!crew) {
      console.log("No active crew found for type:", crewTypeName);
      return twimlResponse("No active crew found");
    }

    console.log(`Found crew: id=${crew.id}, type=${crewTypeName}`);

    // Check if sender is a crew member (by phone number)
    const crewMember = await findCrewMemberByPhone(
      adminClient,
      crew.id,
      normalizedFrom,
    );

    if (crewMember) {
      // CREW MEMBER MESSAGE
      console.log(
        `CREW MEMBER DETECTED: ${crewMember.firstname} ${crewMember.lastname} (supabase_id: ${crewMember.supabase_id})`,
      );
      console.log(
        `Routing to handleCrewMemberMessage (will create crew_message, NOT problem)`,
      );
      return await handleCrewMemberMessage(
        adminClient,
        crew,
        crewMember,
        body,
        from,
      );
    } else {
      // NON-CREW MEMBER (REFEREE/REPORTER) MESSAGE
      console.log(
        "NON-CREW MEMBER DETECTED - Routing to handleReporterMessage (will create problem)",
      );
      return await handleReporterMessage(adminClient, crew, from, body);
    }
  } catch (error) {
    console.error("receive-sms error:", error);
    return twimlResponse("An error occurred processing your message");
  }
});

// Handle message from a crew member
async function handleCrewMemberMessage(
  adminClient: any,
  crew: any,
  crewMember: any,
  body: string,
  fromPhone: string,
): Promise<Response> {
  // Check for +n prefix (reply to specific problem)
  const plusNMatch = body.match(/^\+(\d)\s*(.*)$/s);

  if (plusNMatch) {
    // +n message - route to most recent open problem from the reporter who was assigned that slot
    const slot = parseInt(plusNMatch[1]);
    const message = plusNMatch[2].trim();

    if (slot < 1 || slot > 4) {
      return twimlResponse("Invalid slot number. Use +1, +2, +3, or +4");
    }

    // Look up the slot to get the reporter's phone
    const { data: slotData } = await adminClient
      .from("sms_reply_slots")
      .select("phone")
      .eq("crew_id", crew.id)
      .eq("slot", slot)
      .maybeSingle();

    if (!slotData || !slotData.phone) {
      return twimlResponse(`No active reporter for +${slot}`);
    }

    // Find the most recent open problem from this reporter for this crew
    const { data: problem } = await adminClient
      .from("problem")
      .select("id, reporter_phone, strip")
      .eq("crew", crew.id)
      .eq("reporter_phone", slotData.phone)
      .is("enddatetime", null)
      .order("startdatetime", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!problem) {
      return twimlResponse(`No open problem for +${slot}`);
    }

    // Insert message into the problem's messages table
    const { error: msgError } = await adminClient.from("messages").insert({
      problem: problem.id,
      crew: crew.id,
      author: crewMember.supabase_id,
      message: message,
      include_reporter: true, // Crew member replies should be visible to reporter
    });

    if (msgError) {
      console.error("Error inserting message:", msgError);
      return twimlResponse("Failed to send message");
    }

    // Also send the message as SMS to the reporter
    if (problem.reporter_phone) {
      await sendSmsToReporter(
        adminClient,
        problem.reporter_phone,
        message,
        crewMember,
        crew,
      );
    }

    // Notify other SMS mode crew members about this reply
    await notifyOtherSmsCrewMembers(
      adminClient,
      crew.id,
      crewMember.supabase_id,
      message,
      crewMember,
      problem.strip,
    );

    // No response to SMS crew member - matches legacy behavior
    return emptyTwimlResponse();
  } else {
    // No +n prefix - treat as crew broadcast message
    const { error: crewMsgError } = await adminClient
      .from("crew_messages")
      .insert({
        crew: crew.id,
        author: crewMember.supabase_id,
        message: body,
      });

    if (crewMsgError) {
      console.error("Error inserting crew message:", crewMsgError);
      return twimlResponse("Failed to send crew message");
    }

    // No response to SMS crew member - matches legacy behavior
    return emptyTwimlResponse();
  }
}

// Handle message from non-crew member (referee/reporter)
async function handleReporterMessage(
  adminClient: any,
  crew: any,
  fromPhone: string,
  body: string,
): Promise<Response> {
  const normalizedFrom = normalizePhone(fromPhone);

  // Look up reporter name using database function
  // This checks users table first, then sms_reporters, with proper phone normalization
  let reporterName = normalizedFrom;

  const { data: nameResult, error: nameError } = await adminClient.rpc(
    "get_reporter_name",
    { reporter_phone: normalizedFrom },
  );

  if (nameError) {
    console.log(`Error looking up reporter name: ${nameError.message}`);
  } else if (nameResult) {
    reporterName = nameResult;
    console.log(`Found reporter name for ${normalizedFrom}: ${reporterName}`);
  } else {
    console.log(`No name found for ${normalizedFrom}, using phone number`);
  }

  // Check if there's an existing unresolved problem from this phone for this crew
  const { data: existingProblem } = await adminClient
    .from("problem")
    .select("id, strip")
    .eq("crew", crew.id)
    .eq("reporter_phone", normalizedFrom)
    .is("enddatetime", null)
    .order("startdatetime", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (existingProblem) {
    // Add message to existing problem
    const { error: msgError } = await adminClient.from("messages").insert({
      problem: existingProblem.id,
      crew: crew.id,
      author: null, // null author indicates SMS message
      message: `${reporterName}: ${body}`,
      include_reporter: true,
    });

    if (msgError) {
      console.error("Error inserting message:", msgError);
      return twimlResponse("Failed to add message");
    }

    // Assign a new +n slot for this message (increments per message, not per problem)
    const slot = await assignSlot(adminClient, crew.id, normalizedFrom);

    // Notify SMS crew members about the new message
    await notifySmsModeCrewMembers(
      adminClient,
      crew.id,
      existingProblem.id,
      existingProblem.strip,
      reporterName,
      body,
      slot,
    );

    // No response to reporter - matches legacy behavior
    return emptyTwimlResponse();
  } else {
    // Create new problem
    console.log(`Creating new problem for reporter ${normalizedFrom}`);

    // Parse strip from message (regex: "L4", "strip 5", "A3", "Finals", etc.)
    const strip = parseStripFromMessage(body);
    console.log(`Parsed strip: ${strip} from message: ${body}`);

    // Find the "SMS Report - Needs Triage" symptom for this crew type
    console.log(`Looking for SMS symptom for crew_type: ${crew.crew_type}`);
    const symptomId = await findSmsSymptom(adminClient, crew.crew_type);
    if (!symptomId) {
      console.error(
        "Could not find SMS symptom for crew type:",
        crew.crew_type,
      );
      return twimlResponse("Configuration error - please contact support");
    }
    console.log(`Found symptom ID: ${symptomId}`);

    // Create the problem
    console.log(
      `Inserting problem: event=${crew.event}, crew=${crew.id}, strip=${strip}, symptom=${symptomId}`,
    );
    const { data: newProblem, error: problemError } = await adminClient
      .from("problem")
      .insert({
        event: crew.event,
        crew: crew.id,
        strip: strip,
        symptom: symptomId,
        reporter_phone: normalizedFrom,
        startdatetime: new Date().toISOString(),
      })
      .select("id")
      .single();

    if (problemError) {
      console.error("Error creating problem:", problemError);
      return twimlResponse("Failed to report problem");
    }
    console.log(`Created problem ID: ${newProblem.id}`);

    // Add the initial message
    await adminClient.from("messages").insert({
      problem: newProblem.id,
      crew: crew.id,
      author: null,
      message: `${reporterName}: ${body}`,
      include_reporter: true,
    });

    // Assign a +n slot for this reporter (increments per message)
    const slot = await assignSlot(adminClient, crew.id, normalizedFrom);

    // Notify SMS crew members about the new problem
    await notifySmsModeCrewMembers(
      adminClient,
      crew.id,
      newProblem.id,
      strip,
      reporterName,
      body,
      slot,
    );

    // No response to reporter - matches legacy behavior
    return emptyTwimlResponse();
  }
}

// Find crew by crew type name
async function findCrewByType(
  adminClient: any,
  crewTypeName: string,
): Promise<any> {
  // Get crew type ID
  const { data: crewType } = await adminClient
    .from("crewtypes")
    .select("id")
    .eq("crewtype", crewTypeName)
    .single();

  if (!crewType) return null;

  // Find the most recent crew of this type (assumes one active per event)
  // In a real scenario, you might filter by active event
  const { data: crew } = await adminClient
    .from("crews")
    .select("id, event, crew_type")
    .eq("crew_type", crewType.id)
    .order("id", { ascending: false })
    .limit(1)
    .single();

  return crew;
}

// Find crew member by phone number
async function findCrewMemberByPhone(
  adminClient: any,
  crewId: number,
  phone: string,
): Promise<any> {
  console.log(`Looking for crew member with phone ${phone} in crew ${crewId}`);

  // Get all crew members for this crew
  // Query crewmembers and then fetch user data separately to avoid FK ambiguity
  const { data: crewMembers, error } = await adminClient
    .from("crewmembers")
    .select("crewmember")
    .eq("crew", crewId);

  if (error) {
    console.error("Error fetching crew members:", error);
    return null;
  }

  if (!crewMembers || crewMembers.length === 0) {
    console.log(`No crew members found for crew ${crewId}`);
    return null;
  }

  console.log(
    `Found ${crewMembers.length} crew members, fetching user data...`,
  );

  // Fetch user data for each crew member
  const memberIds = crewMembers.map((cm: any) => cm.crewmember);
  const { data: users, error: usersError } = await adminClient
    .from("users")
    .select("supabase_id, firstname, lastname, phonenbr")
    .in("supabase_id", memberIds);

  if (usersError) {
    console.error("Error fetching user data:", usersError);
    return null;
  }

  if (!users || users.length === 0) {
    console.log(`No user data found for crew members`);
    return null;
  }

  console.log(`Found ${users.length} users, checking phones...`);

  // Find user whose phone matches
  for (const user of users) {
    if (user.phonenbr) {
      const memberPhone = normalizePhone(user.phonenbr);
      console.log(
        `  Comparing ${memberPhone} with ${phone} (${user.firstname} ${user.lastname})`,
      );
      if (memberPhone === phone) {
        console.log(`  MATCH FOUND: ${user.firstname} ${user.lastname}`);
        return user;
      }
    } else {
      console.log(`  User ${user.supabase_id} has no phone number`);
    }
  }

  console.log(`No crew member found with phone ${phone}`);
  return null;
}

// Parse strip number from message text
function parseStripFromMessage(body: string): string {
  // Try various patterns
  // "L4", "L 4", "left 4"
  const leftMatch = body.match(/\b[Ll](?:eft)?\s*(\d+)\b/);
  if (leftMatch) return `L${leftMatch[1]}`;

  // "R4", "R 4", "right 4"
  const rightMatch = body.match(/\b[Rr](?:ight)?\s*(\d+)\b/);
  if (rightMatch) return `R${rightMatch[1]}`;

  // "A3", "B2", etc.
  const letterMatch = body.match(/\b([A-Za-z])(\d+)\b/);
  if (letterMatch) return `${letterMatch[1].toUpperCase()}${letterMatch[2]}`;

  // "strip 5", "Strip #5", "strip#5"
  const stripMatch = body.match(/\bstrip\s*#?\s*(\d+)\b/i);
  if (stripMatch) return stripMatch[1];

  // Just a number at the start
  const numMatch = body.match(/^(\d+)\b/);
  if (numMatch) return numMatch[1];

  // "finals", "final"
  if (/\bfinals?\b/i.test(body)) return "Finals";

  // Default
  return "Unknown";
}

// Find the SMS symptom for a crew type
async function findSmsSymptom(
  adminClient: any,
  crewTypeId: number,
): Promise<number | null> {
  // Find General symptomclass for this crew type
  const { data: symptomClass } = await adminClient
    .from("symptomclass")
    .select("id")
    .eq("symptomclassstring", "General")
    .eq("crewType", crewTypeId)
    .maybeSingle();

  if (!symptomClass) return null;

  // Find SMS symptom in this class
  const { data: symptom } = await adminClient
    .from("symptom")
    .select("id")
    .eq("symptomclass", symptomClass.id)
    .eq("symptomstring", "SMS Report - Needs Triage")
    .maybeSingle();

  return symptom?.id || null;
}

// Assign a +n slot for a reporter (increments on every message)
async function assignSlot(
  adminClient: any,
  crewId: number,
  phone: string,
): Promise<number> {
  console.log(`Assigning slot for crew ${crewId}, phone ${phone}`);

  // Get or initialize the slot counter for this crew
  const { data: counter, error: counterError } = await adminClient
    .from("sms_crew_slot_counter")
    .select("next_slot")
    .eq("crew_id", crewId)
    .maybeSingle();

  if (counterError) {
    console.error("Error fetching slot counter:", counterError);
  }

  let nextSlot = counter?.next_slot || 1;
  console.log(
    `Current slot counter: ${counter?.next_slot}, using slot: ${nextSlot}`,
  );

  // Upsert the slot assignment (tracks reporter phone, not problem)
  const { error: slotError } = await adminClient.from("sms_reply_slots").upsert(
    {
      crew_id: crewId,
      slot: nextSlot,
      phone: phone,
      assigned_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    },
    { onConflict: "crew_id,slot" },
  );

  if (slotError) {
    console.error("Error upserting slot:", slotError);
  }

  // Update the counter (rotate 1-4)
  const newNextSlot = (nextSlot % 4) + 1;
  console.log(`Updating counter to: ${newNextSlot}`);

  const { data: updateData, error: updateError } = await adminClient
    .from("sms_crew_slot_counter")
    .upsert(
      { crew_id: crewId, next_slot: newNextSlot },
      { onConflict: "crew_id" },
    )
    .select();

  if (updateError) {
    console.error("Error updating slot counter:", updateError);
  } else {
    console.log(`Counter update result:`, updateData);
  }

  return nextSlot;
}

// Notify other SMS mode crew members about a crew member's reply (excludes the sender)
async function notifyOtherSmsCrewMembers(
  adminClient: any,
  crewId: number,
  senderUserId: string,
  message: string,
  senderMember: any,
  strip: string,
): Promise<void> {
  console.log(
    `notifyOtherSmsCrewMembers called: crewId=${crewId}, sender=${senderUserId}, strip=${strip}`,
  );

  const twilioAccountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
  const twilioAuthToken = Deno.env.get("TWILIO_AUTH_TOKEN");

  if (!twilioAccountSid || !twilioAuthToken) {
    console.log("Twilio not configured, skipping SMS notifications");
    return;
  }

  // Get crew info for the From phone
  const { data: crew } = await adminClient
    .from("crews")
    .select(`crewtypes:crew_type (crewtype)`)
    .eq("id", crewId)
    .single();

  const crewTypeName = crew?.crewtypes?.crewtype;
  const CREW_TYPE_TO_PHONE: Record<string, string> = {
    Armorer: "+17542276679",
    Medical: "+13127577223",
    Natloff: "+16504803067",
  };
  const fromPhone = crewTypeName ? CREW_TYPE_TO_PHONE[crewTypeName] : null;

  if (!fromPhone) {
    console.log("No From phone for crew type:", crewTypeName);
    return;
  }

  // Get SMS mode crew members - query separately to avoid FK ambiguity
  const { data: crewMembers, error: cmError } = await adminClient
    .from("crewmembers")
    .select("crewmember")
    .eq("crew", crewId);

  if (cmError || !crewMembers || crewMembers.length === 0) return;

  // Get user data for these crew members
  const memberIds = crewMembers.map((cm: any) => cm.crewmember);
  const { data: users } = await adminClient
    .from("users")
    .select("supabase_id, phonenbr, is_sms_mode, firstname, lastname")
    .in("supabase_id", memberIds);

  if (!users) return;

  // Format: "SenderName: message"
  const senderName =
    `${senderMember.firstname || ""} ${senderMember.lastname || ""}`.trim() ||
    "Crew";
  const smsBody = `${senderName}: ${message}`;

  for (const user of users) {
    // Skip the sender and only send to SMS mode users
    if (user.supabase_id === senderUserId) continue;
    if (!user.is_sms_mode || !user.phonenbr) continue;

    try {
      await sendTwilioSms(
        twilioAccountSid,
        twilioAuthToken,
        fromPhone,
        user.phonenbr,
        smsBody,
        adminClient,
      );
      console.log("Notified other SMS crew member:", user.phonenbr);
    } catch (e) {
      console.error("Failed to notify SMS crew member:", user.phonenbr, e);
    }
  }
}

// Notify SMS mode crew members about a new message
async function notifySmsModeCrewMembers(
  adminClient: any,
  crewId: number,
  problemId: number,
  strip: string,
  reporterName: string,
  message: string,
  slot: number | undefined,
): Promise<void> {
  console.log(
    `notifySmsModeCrewMembers called: crewId=${crewId}, problemId=${problemId}, strip=${strip}`,
  );

  const twilioAccountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
  const twilioAuthToken = Deno.env.get("TWILIO_AUTH_TOKEN");

  if (!twilioAccountSid || !twilioAuthToken) {
    console.log("Twilio not configured, skipping SMS notifications");
    return;
  }
  console.log("Twilio credentials found");

  // Get crew info for the From phone
  const { data: crew } = await adminClient
    .from("crews")
    .select(
      `
      crewtypes:crew_type (crewtype)
    `,
    )
    .eq("id", crewId)
    .single();

  const crewTypeName = crew?.crewtypes?.crewtype;
  const CREW_TYPE_TO_PHONE: Record<string, string> = {
    Armorer: "+17542276679",
    Medical: "+13127577223",
    Natloff: "+16504803067",
  };
  const fromPhone = crewTypeName ? CREW_TYPE_TO_PHONE[crewTypeName] : null;

  if (!fromPhone) {
    console.log("No From phone for crew type:", crewTypeName);
    return;
  }

  // Get SMS mode crew members - query separately to avoid FK ambiguity
  const { data: crewMembers, error: cmError } = await adminClient
    .from("crewmembers")
    .select("crewmember")
    .eq("crew", crewId);

  console.log(
    `Found ${crewMembers?.length || 0} crew members for notifications`,
    cmError,
  );

  if (!crewMembers || crewMembers.length === 0) return;

  // Get user data for these crew members
  const memberIds = crewMembers.map((cm: any) => cm.crewmember);
  const { data: users, error: usersError } = await adminClient
    .from("users")
    .select("supabase_id, phonenbr, is_sms_mode")
    .in("supabase_id", memberIds);

  console.log(
    `Found ${users?.length || 0} users, checking is_sms_mode...`,
    usersError,
  );
  if (users) {
    for (const u of users) {
      console.log(
        `  User ${u.supabase_id}: phone=${u.phonenbr}, is_sms_mode=${u.is_sms_mode}`,
      );
    }
  }

  if (!users) return;

  // Format: "<name or number>: <message>, +n to reply"
  const slotSuffix = slot ? `, +${slot} to reply` : "";
  const smsBody = `${reporterName}: ${message}${slotSuffix}`;

  for (const user of users) {
    if (user.is_sms_mode && user.phonenbr) {
      try {
        await sendTwilioSms(
          twilioAccountSid,
          twilioAuthToken,
          fromPhone,
          user.phonenbr,
          smsBody,
          adminClient,
        );
        console.log("Notified crew member:", user.phonenbr);
      } catch (e) {
        console.error("Failed to notify crew member:", user.phonenbr, e);
      }
    }
  }
}

// Send SMS to reporter
async function sendSmsToReporter(
  adminClient: any,
  reporterPhone: string,
  message: string,
  crewMember: any,
  crew: any,
): Promise<void> {
  const twilioAccountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
  const twilioAuthToken = Deno.env.get("TWILIO_AUTH_TOKEN");

  if (!twilioAccountSid || !twilioAuthToken) return;

  // Get the From phone
  const { data: crewData } = await adminClient
    .from("crews")
    .select(`crewtypes:crew_type (crewtype)`)
    .eq("id", crew.id)
    .single();

  const crewTypeName = crewData?.crewtypes?.crewtype;
  const CREW_TYPE_TO_PHONE: Record<string, string> = {
    Armorer: "+17542276679",
    Medical: "+13127577223",
    Natloff: "+16504803067",
  };
  const fromPhone = crewTypeName ? CREW_TYPE_TO_PHONE[crewTypeName] : null;

  if (!fromPhone) return;

  // Use full name (first + last)
  const fullName =
    `${crewMember.firstname || ""} ${crewMember.lastname || ""}`.trim() ||
    "Crew";
  const smsBody = `${fullName}: ${message}`;

  try {
    await sendTwilioSms(
      twilioAccountSid,
      twilioAuthToken,
      fromPhone,
      reporterPhone,
      smsBody,
      adminClient,
    );
    console.log("SMS sent to reporter:", reporterPhone);
  } catch (e) {
    console.error("Failed to send SMS to reporter:", e);
  }
}

// Check if phone is a simulator phone (2025551001-2025551005)
function isSimulatorPhone(phone: string): boolean {
  const normalized = phone.replace(/\D/g, "").replace(/^1/, "");
  return /^202555100[1-5]$/.test(normalized);
}

// Send Twilio SMS (or route to simulator)
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
    body: new URLSearchParams({ To: to, From: from, Body: body }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Twilio error: ${response.status} - ${errorText}`);
  }

  return await response.json();
}

// Normalize phone number to digits only
function normalizePhone(phone: string): string {
  return phone.replace(/\D/g, "").replace(/^1/, ""); // Remove non-digits, strip leading 1
}

// Generate TwiML response
function twimlResponse(message: string): Response {
  const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Message>${escapeXml(message)}</Message>
</Response>`;

  return new Response(twiml, {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "text/xml",
    },
  });
}

// Empty TwiML response - no message sent back
function emptyTwimlResponse(): Response {
  const twiml = `<?xml version="1.0" encoding="UTF-8"?>
<Response></Response>`;

  return new Response(twiml, {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "text/xml",
    },
  });
}

function escapeXml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}
