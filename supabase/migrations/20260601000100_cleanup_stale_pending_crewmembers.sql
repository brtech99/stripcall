-- Add cleanup of stale pending_crewmembers (crew invites that were never accepted)
-- to the daily keep_database_active function.

CREATE OR REPLACE FUNCTION public.keep_database_active()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Simple query to keep database active
  PERFORM count(*) FROM users LIMIT 1;

  -- Log the activity
  INSERT INTO public.keep_alive_log (timestamp)
  VALUES (now())
  ON CONFLICT DO NOTHING;

  -- Clean up pending_users older than 6 months (never completed signup)
  DELETE FROM public.pending_users
  WHERE created_at < now() - interval '6 months';

  -- Clean up expired signup OTP codes older than 1 day
  DELETE FROM public.signup_otp_codes
  WHERE created_at < now() - interval '1 day';

  -- Clean up crew invites older than 6 months (invitee never signed up)
  DELETE FROM public.pending_crewmembers
  WHERE invited_at < now() - interval '6 months';

  RAISE NOTICE 'Database keep-alive executed at %', now();
END;
$function$;
