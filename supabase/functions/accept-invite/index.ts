import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Called by an UNAUTHENTICATED invitee from the dedicated invite screen
// (verify_jwt=false). Creates a pre-confirmed account ONLY when the email has a
// genuine pending crew invite, then lets the normal reconciliation trigger add them
// to their crew(s). No confirmation email — the chief already vouched for them.
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const email = String(body.email ?? "").trim().toLowerCase();
    const password = String(body.password ?? "");
    const firstname = (body.firstname ?? null) as string | null;
    const lastname = (body.lastname ?? null) as string | null;

    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      return json({ error: "A valid email is required" }, 400);
    }
    if (password.length < 8) {
      return json({ error: "Password must be at least 8 characters" }, 400);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    // Gate: only emails with a real pending invite may create a pre-confirmed account.
    const { data: invite } = await admin
      .from("pending_crewmembers")
      .select("id")
      .ilike("email", email)
      .limit(1)
      .maybeSingle();
    if (!invite) {
      return json({ error: "This invitation is no longer valid" }, 403);
    }

    // (If the email is already registered, createUser below returns an error and we
    //  steer them to login.)
    const { data: created, error: createErr } = await admin.auth.admin
      .createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { firstname, lastname },
      });

    if (createErr || !created?.user) {
      const msg = createErr?.message ?? "Could not create account";
      // Most common: the email already has an account.
      const alreadyExists = /already|registered|exists/i.test(msg);
      return json(
        {
          error: alreadyExists
            ? "You already have an account — please log in instead."
            : msg,
        },
        alreadyExists ? 409 : 500,
      );
    }

    // Insert the public.users row, which fires the reconciliation trigger that adds
    // them to every crew that invited this email and clears the pending invite(s).
    const { error: userErr } = await admin.from("users").insert({
      supabase_id: created.user.id,
      firstname: firstname ?? "",
      lastname: lastname ?? "",
      phonenbr: null,
      superuser: false,
      organizer: false,
      is_sms_mode: false,
    });

    if (userErr) {
      console.error("Failed to insert users row:", userErr);
      return json({ error: "Account created but profile setup failed" }, 500);
    }

    return json({ status: "ok" });
  } catch (e) {
    console.error("accept-invite error:", e);
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
