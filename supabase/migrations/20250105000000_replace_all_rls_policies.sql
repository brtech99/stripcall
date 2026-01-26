-- Comprehensive RLS Policy Replacement
-- This migration drops all existing policies and recreates them with correct logic

-- Ensure helper functions exist (CREATE OR REPLACE is safe)
CREATE OR REPLACE FUNCTION public.is_superuser(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE supabase_id = user_id::text AND superuser = true
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.is_organizer(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE supabase_id = user_id::text AND organizer = true
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.is_crew_chief(user_id uuid, crew_id bigint)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM crews
    WHERE id = crew_id AND crew_chief = user_id::text
  );
END;
$function$;

-- Drop ALL existing policies
DROP POLICY IF EXISTS "action_read_policy" ON "public"."action";
DROP POLICY IF EXISTS "action_write_policy" ON "public"."action";
DROP POLICY IF EXISTS "crewmembers_create_policy" ON "public"."crewmembers";
DROP POLICY IF EXISTS "crewmembers_delete_policy" ON "public"."crewmembers";
DROP POLICY IF EXISTS "crewmembers_read_policy" ON "public"."crewmembers";
DROP POLICY IF EXISTS "crewmembers_update_policy" ON "public"."crewmembers";
DROP POLICY IF EXISTS "crews_create_policy" ON "public"."crews";
DROP POLICY IF EXISTS "crews_delete_policy" ON "public"."crews";
DROP POLICY IF EXISTS "crews_read_policy" ON "public"."crews";
DROP POLICY IF EXISTS "crews_update_policy" ON "public"."crews";
DROP POLICY IF EXISTS "crewtypes_read_policy" ON "public"."crewtypes";
DROP POLICY IF EXISTS "crewtypes_write_policy" ON "public"."crewtypes";
DROP POLICY IF EXISTS "device_tokens_policy" ON "public"."device_tokens";
DROP POLICY IF EXISTS "events_create_policy" ON "public"."events";
DROP POLICY IF EXISTS "events_delete_policy" ON "public"."events";
DROP POLICY IF EXISTS "events_read_policy" ON "public"."events";
DROP POLICY IF EXISTS "events_update_policy" ON "public"."events";
DROP POLICY IF EXISTS "messages_create_policy" ON "public"."messages";
DROP POLICY IF EXISTS "messages_read_policy" ON "public"."messages";
-- notification_preferences table may not exist yet (created in later migration)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notification_preferences') THEN
    DROP POLICY IF EXISTS "notification_preferences_policy" ON "public"."notification_preferences";
  END IF;
END $$;
DROP POLICY IF EXISTS "oldproblemsymptom_read_policy" ON "public"."oldproblemsymptom";
DROP POLICY IF EXISTS "oldproblemsymptom_insert_policy" ON "public"."oldproblemsymptom";
DROP POLICY IF EXISTS "oldproblemsymptom_update_policy" ON "public"."oldproblemsymptom";
DROP POLICY IF EXISTS "oldproblemsymptom_delete_policy" ON "public"."oldproblemsymptom";
-- pending_users table may not exist yet (created in later migration)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pending_users') THEN
    DROP POLICY IF EXISTS "PendingUsersDeletePolicy" ON "public"."pending_users";
    DROP POLICY IF EXISTS "PendingUsersInsertPolicy" ON "public"."pending_users";
    DROP POLICY IF EXISTS "PendingUsersReadPolicy" ON "public"."pending_users";
  END IF;
END $$;
DROP POLICY IF EXISTS "problem_create_policy" ON "public"."problem";
DROP POLICY IF EXISTS "problem_delete_policy" ON "public"."problem";
DROP POLICY IF EXISTS "problem_read_policy" ON "public"."problem";
DROP POLICY IF EXISTS "problem_update_policy" ON "public"."problem";
-- responders table may not exist yet (created in later migration)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'responders') THEN
    DROP POLICY IF EXISTS "responders_create_policy" ON "public"."responders";
    DROP POLICY IF EXISTS "responders_read_policy" ON "public"."responders";
    DROP POLICY IF EXISTS "responders_update_policy" ON "public"."responders";
    DROP POLICY IF EXISTS "responders_delete_policy" ON "public"."responders";
  END IF;
END $$;
DROP POLICY IF EXISTS "symptom_read_policy" ON "public"."symptom";
DROP POLICY IF EXISTS "symptom_write_policy" ON "public"."symptom";
DROP POLICY IF EXISTS "symptomclass_read_policy" ON "public"."symptomclass";
DROP POLICY IF EXISTS "symptomclass_write_policy" ON "public"."symptomclass";
DROP POLICY IF EXISTS "users_create_policy" ON "public"."users";
DROP POLICY IF EXISTS "users_delete_policy" ON "public"."users";
DROP POLICY IF EXISTS "users_read_policy" ON "public"."users";
DROP POLICY IF EXISTS "users_update_policy" ON "public"."users";

-- Drop any existing crew_messages policies
DROP POLICY IF EXISTS "Users can delete their own crew messages" ON "public"."crew_messages";
DROP POLICY IF EXISTS "Users can insert crew messages for their crews" ON "public"."crew_messages";
DROP POLICY IF EXISTS "Users can update their own crew messages" ON "public"."crew_messages";
DROP POLICY IF EXISTS "Users can view crew messages for their crews" ON "public"."crew_messages";

-- Recreate ALL policies with correct logic

-- ACTION table policies - read for all, write for superusers only
CREATE POLICY "action_read_policy"
ON "public"."action"
AS PERMISSIVE
FOR SELECT
TO public
USING ((auth.role() = 'authenticated'::text));

CREATE POLICY "action_write_policy"
ON "public"."action"
AS PERMISSIVE
FOR ALL
TO public
USING (is_superuser(auth.uid()));

-- CREWMEMBERS table policies - managed by crew chiefs and superusers
CREATE POLICY "crewmembers_create_policy"
ON "public"."crewmembers"
AS PERMISSIVE
FOR INSERT
TO public
WITH CHECK ((is_superuser(auth.uid()) OR is_crew_chief(auth.uid(), crew)));

CREATE POLICY "crewmembers_delete_policy"
ON "public"."crewmembers"
AS PERMISSIVE
FOR DELETE
TO public
USING ((is_superuser(auth.uid()) OR is_crew_chief(auth.uid(), crew)));

CREATE POLICY "crewmembers_read_policy"
ON "public"."crewmembers"
AS PERMISSIVE
FOR SELECT
TO public
USING (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR is_crew_chief(auth.uid(), crew) OR (crewmember = (auth.uid())::text))));

CREATE POLICY "crewmembers_update_policy"
ON "public"."crewmembers"
AS PERMISSIVE
FOR UPDATE
TO public
USING ((is_superuser(auth.uid()) OR is_crew_chief(auth.uid(), crew)))
WITH CHECK ((is_superuser(auth.uid()) OR is_crew_chief(auth.uid(), crew)));

-- CREWS table policies - managed by superusers, organizers, and crew chiefs
CREATE POLICY "crews_create_policy"
ON "public"."crews"
AS PERMISSIVE
FOR INSERT
TO public
WITH CHECK (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR is_organizer(auth.uid()))));

CREATE POLICY "crews_delete_policy"
ON "public"."crews"
AS PERMISSIVE
FOR DELETE
TO public
USING (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR (EXISTS ( SELECT 1
   FROM events e
  WHERE ((e.id = crews.event) AND (e.organizer = (auth.uid())::text)))) OR (crews.crew_chief = (auth.uid())::text))));

CREATE POLICY "crews_read_policy"
ON "public"."crews"
AS PERMISSIVE
FOR SELECT
TO public
USING ((auth.role() = 'authenticated'::text));

CREATE POLICY "crews_update_policy"
ON "public"."crews"
AS PERMISSIVE
FOR UPDATE
TO public
USING (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR (EXISTS ( SELECT 1
   FROM events e
  WHERE ((e.id = crews.event) AND (e.organizer = (auth.uid())::text)))) OR (crews.crew_chief = (auth.uid())::text))))
WITH CHECK (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR (EXISTS ( SELECT 1
   FROM events e
  WHERE ((e.id = crews.event) AND (e.organizer = (auth.uid())::text)))) OR (crews.crew_chief = (auth.uid())::text))));

-- CREWTYPES table policies - read for all, write for superusers only
CREATE POLICY "crewtypes_read_policy"
ON "public"."crewtypes"
AS PERMISSIVE
FOR SELECT
TO public
USING ((auth.role() = 'authenticated'::text));

CREATE POLICY "crewtypes_write_policy"
ON "public"."crewtypes"
AS PERMISSIVE
FOR ALL
TO public
USING (is_superuser(auth.uid()));

-- DEVICE_TOKENS table policies - users manage their own tokens
CREATE POLICY "device_tokens_policy"
ON "public"."device_tokens"
AS PERMISSIVE
FOR ALL
TO public
USING ((user_id = auth.uid()));

-- EVENTS table policies - organizers and superusers manage events
CREATE POLICY "events_create_policy"
ON "public"."events"
AS PERMISSIVE
FOR INSERT
TO public
WITH CHECK (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR is_organizer(auth.uid()))));

CREATE POLICY "events_delete_policy"
ON "public"."events"
AS PERMISSIVE
FOR DELETE
TO public
USING (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR (organizer = (auth.uid())::text))));

CREATE POLICY "events_read_policy"
ON "public"."events"
AS PERMISSIVE
FOR SELECT
TO public
USING ((auth.role() = 'authenticated'::text));

CREATE POLICY "events_update_policy"
ON "public"."events"
AS PERMISSIVE
FOR UPDATE
TO public
USING (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR (organizer = (auth.uid())::text))))
WITH CHECK (((auth.role() = 'authenticated'::text) AND (is_superuser(auth.uid()) OR (organizer = (auth.uid())::text))));

-- MESSAGES table policies - authenticated users can create, all can read
CREATE POLICY "messages_create_policy"
ON "public"."messages"
AS PERMISSIVE
FOR INSERT
TO public
WITH CHECK ((auth.role() = 'authenticated'::text));

CREATE POLICY "messages_read_policy"
ON "public"."messages"
AS PERMISSIVE
FOR SELECT
TO public
USING ((auth.role() = 'authenticated'::text));

-- NOTIFICATION_PREFERENCES table policies - authenticated users only (table may not exist yet)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notification_preferences') THEN
    CREATE POLICY "notification_preferences_policy"
    ON "public"."notification_preferences"
    AS PERMISSIVE
    FOR ALL
    TO public
    USING ((auth.role() = 'authenticated'::text));
  END IF;
END $$;

-- OLDPROBLEMSYMPTOM table policies - read for all, write for superusers only
CREATE POLICY "oldproblemsymptom_read_policy"
ON "public"."oldproblemsymptom"
AS PERMISSIVE
FOR SELECT
TO public
USING ((auth.role() = 'authenticated'::text));

CREATE POLICY "oldproblemsymptom_insert_policy"
ON "public"."oldproblemsymptom"
AS PERMISSIVE
FOR INSERT
TO public
WITH CHECK (is_superuser(auth.uid()));

CREATE POLICY "oldproblemsymptom_update_policy"
ON "public"."oldproblemsymptom"
AS PERMISSIVE
FOR UPDATE
TO public
USING (((auth.role() = 'authenticated'::text) AND is_superuser(auth.uid())))
WITH CHECK (((auth.role() = 'authenticated'::text) AND is_superuser(auth.uid())));

CREATE POLICY "oldproblemsymptom_delete_policy"
ON "public"."oldproblemsymptom"
AS PERMISSIVE
FOR DELETE
TO public
USING (((auth.role() = 'authenticated'::text) AND is_superuser(auth.uid())));

-- PENDING_USERS table policies - public insert, authenticated management (table may not exist yet)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pending_users') THEN
    CREATE POLICY "PendingUsersDeletePolicy"
    ON "public"."pending_users"
    AS PERMISSIVE
    FOR DELETE
    TO public
    USING ((auth.role() = 'authenticated'::text));

    CREATE POLICY "PendingUsersInsertPolicy"
    ON "public"."pending_users"
    AS PERMISSIVE
    FOR INSERT
    TO public
    WITH CHECK (true);

    CREATE POLICY "PendingUsersReadPolicy"
    ON "public"."pending_users"
    AS PERMISSIVE
    FOR SELECT
    TO public
    USING ((auth.role() = 'authenticated'::text));
  END IF;
END $$;

-- PROBLEM table policies - authenticated users can manage
CREATE POLICY "problem_create_policy"
ON "public"."problem"
AS PERMISSIVE
FOR INSERT
TO public
WITH CHECK ((auth.role() = 'authenticated'::text));

CREATE POLICY "problem_delete_policy"
ON "public"."problem"
AS PERMISSIVE
FOR DELETE
TO public
USING ((auth.role() = 'authenticated'::text));

CREATE POLICY "problem_read_policy"
ON "public"."problem"
AS PERMISSIVE
FOR SELECT
TO public
USING ((auth.role() = 'authenticated'::text));

CREATE POLICY "problem_update_policy"
ON "public"."problem"
AS PERMISSIVE
FOR UPDATE
TO public
USING ((auth.role() = 'authenticated'::text))
WITH CHECK ((auth.role() = 'authenticated'::text));

-- RESPONDERS table policies - authenticated users can manage (table may not exist yet)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'responders') THEN
    CREATE POLICY "responders_create_policy"
    ON "public"."responders"
    AS PERMISSIVE
    FOR INSERT
    TO public
    WITH CHECK ((auth.role() = 'authenticated'::text));

    CREATE POLICY "responders_read_policy"
    ON "public"."responders"
    AS PERMISSIVE
    FOR SELECT
    TO public
    USING ((auth.role() = 'authenticated'::text));

    CREATE POLICY "responders_update_policy"
    ON "public"."responders"
    AS PERMISSIVE
    FOR UPDATE
    TO public
    USING (((auth.role() = 'authenticated'::text) AND is_superuser(auth.uid())))
    WITH CHECK (((auth.role() = 'authenticated'::text) AND is_superuser(auth.uid())));

    CREATE POLICY "responders_delete_policy"
    ON "public"."responders"
    AS PERMISSIVE
    FOR DELETE
    TO public
    USING ((auth.role() = 'authenticated'::text));
  END IF;
END $$;

-- SYMPTOM table policies - read for all, write for superusers only
CREATE POLICY "symptom_read_policy"
ON "public"."symptom"
AS PERMISSIVE
FOR SELECT
TO public
USING ((auth.role() = 'authenticated'::text));

CREATE POLICY "symptom_write_policy"
ON "public"."symptom"
AS PERMISSIVE
FOR ALL
TO public
USING (is_superuser(auth.uid()));

-- SYMPTOMCLASS table policies - read for all, write for superusers only
CREATE POLICY "symptomclass_read_policy"
ON "public"."symptomclass"
AS PERMISSIVE
FOR SELECT
TO public
USING ((auth.role() = 'authenticated'::text));

CREATE POLICY "symptomclass_write_policy"
ON "public"."symptomclass"
AS PERMISSIVE
FOR ALL
TO public
USING (is_superuser(auth.uid()));

-- USERS table policies - authenticated users can manage
CREATE POLICY "users_create_policy"
ON "public"."users"
AS PERMISSIVE
FOR INSERT
TO public
WITH CHECK ((auth.role() = 'authenticated'::text));

CREATE POLICY "users_delete_policy"
ON "public"."users"
AS PERMISSIVE
FOR DELETE
TO public
USING ((auth.role() = 'authenticated'::text));

CREATE POLICY "users_read_policy"
ON "public"."users"
AS PERMISSIVE
FOR SELECT
TO public
USING ((auth.role() = 'authenticated'::text));

CREATE POLICY "users_update_policy"
ON "public"."users"
AS PERMISSIVE
FOR UPDATE
TO public
USING ((auth.role() = 'authenticated'::text))
WITH CHECK ((auth.role() = 'authenticated'::text));

-- CREW_MESSAGES table policies - crew-based access
CREATE POLICY "Users can delete their own crew messages"
ON "public"."crew_messages"
AS PERMISSIVE
FOR DELETE
TO public
USING ((author = (auth.uid())::text));

CREATE POLICY "Users can insert crew messages for their crews"
ON "public"."crew_messages"
AS PERMISSIVE
FOR INSERT
TO public
WITH CHECK ((EXISTS ( SELECT 1
   FROM crewmembers cm
  WHERE ((cm.crew = crew_messages.crew) AND (cm.crewmember = (auth.uid())::text)))));

CREATE POLICY "Users can update their own crew messages"
ON "public"."crew_messages"
AS PERMISSIVE
FOR UPDATE
TO public
USING ((author = (auth.uid())::text))
WITH CHECK ((author = (auth.uid())::text));

CREATE POLICY "Users can view crew messages for their crews"
ON "public"."crew_messages"
AS PERMISSIVE
FOR SELECT
TO public
USING ((EXISTS ( SELECT 1
   FROM crewmembers cm
  WHERE ((cm.crew = crew_messages.crew) AND (cm.crewmember = (auth.uid())::text)))));
