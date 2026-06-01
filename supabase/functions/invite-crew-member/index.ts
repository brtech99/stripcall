import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Web app base; the invite link deep-links to the signup page with the email pre-filled.
const APP_BASE_URL = Deno.env.get("APP_BASE_URL") ?? "https://stripcall.us/app";
const EMAIL_FROM = "StripCall <noreply@stripcall.us>";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Unauthorized" }, 401);

    // Identify the caller from their JWT.
    const callerClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user } } = await callerClient.auth.getUser();
    if (!user) return json({ error: "Unauthorized - no valid session" }, 401);

    const body = await req.json();
    const crewId = body.crewId;
    const email = body.email;
    const firstname = body.firstname ?? null;
    const lastname = body.lastname ?? null;

    if (!crewId || !email) {
      return json({ error: "crewId and email are required" }, 400);
    }
    const normalizedEmail = String(email).trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalizedEmail)) {
      return json({ error: "Invalid email address" }, 400);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Authorize: caller must be the crew's chief or a superuser.
    const { data: crew, error: crewErr } = await admin
      .from("crews").select("id, crew_chief").eq("id", crewId).maybeSingle();
    if (crewErr || !crew) return json({ error: "Crew not found" }, 404);

    const { data: caller } = await admin
      .from("users").select("superuser").eq("supabase_id", user.id).maybeSingle();
    const isChief = crew.crew_chief === user.id;
    const isSuper = caller?.superuser === true;
    if (!isChief && !isSuper) {
      return json(
        { error: "Only the crew chief can invite members to this crew" },
        403,
      );
    }

    // If the email already belongs to a registered user, add them now; otherwise
    // record a pending invite. (Logic + reconciliation live in the database.)
    const { data: outcome, error: rpcErr } = await admin.rpc(
      "invite_or_add_crewmember",
      {
        p_crew: crewId,
        p_email: normalizedEmail,
        p_firstname: firstname,
        p_lastname: lastname,
        p_invited_by: user.id,
      },
    );
    if (rpcErr) {
      console.error("invite_or_add_crewmember failed:", rpcErr);
      return json({ error: "Failed to record invite" }, 500);
    }

    if (outcome === "added") {
      return json({ status: "added" });
    }

    // outcome === 'invited' — send the invitation email (best-effort; the invite is
    // already recorded, so the chief can re-send if this fails).
    const emailSent = await sendInviteEmail(normalizedEmail, firstname, lastname);
    return json({ status: "invited", emailSent });
  } catch (e) {
    console.error("invite-crew-member error:", e);
    const message = e instanceof Error ? e.message : String(e);
    return json({ error: message }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function sendInviteEmail(
  email: string,
  firstname: string | null,
  lastname: string | null,
): Promise<boolean> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) {
    console.log("RESEND_API_KEY not set; skipping invite email");
    return false;
  }
  // Only send real email from a deployed (prod) project, not from a local/dev stack.
  const isProd = (Deno.env.get("SUPABASE_URL") ?? "").includes(".supabase.co");
  if (!isProd) {
    console.log("Local/dev environment; recorded invite but not sending email");
    return false;
  }

  const params = new URLSearchParams({ email });
  if (firstname) params.set("firstname", firstname);
  if (lastname) params.set("lastname", lastname);
  const signupUrl = `${APP_BASE_URL}/#/auth/register?${params.toString()}`;

  const greeting = firstname ? `Hi ${firstname},` : "Hi,";
  const html = `
    <p>${greeting}</p>
    <p>You've been added to a crew in <strong>StripCall</strong>. To finish, please create your account:</p>
    <p><a href="${signupUrl}">Create your StripCall account</a></p>
    <p>Use this email address (<strong>${email}</strong>) when you sign up so you're
       automatically connected to your crew.</p>
    <p>If you weren't expecting this, you can safely ignore this email.</p>`;

  try {
    const resp = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: EMAIL_FROM,
        to: [email],
        subject: "You're invited to a StripCall crew",
        html,
      }),
    });
    if (!resp.ok) {
      console.error("Resend error:", resp.status, await resp.text());
      return false;
    }
    return true;
  } catch (e) {
    console.error("Resend send failed:", e);
    return false;
  }
}
