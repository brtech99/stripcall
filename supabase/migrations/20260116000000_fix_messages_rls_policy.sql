-- Fix messages RLS policy to allow problem originators and superusers to send messages
-- even if they're not crew members

DROP POLICY IF EXISTS "messages_create_policy" ON "public"."messages";

CREATE POLICY "messages_create_policy"
ON "public"."messages"
AS PERMISSIVE
FOR INSERT
TO public
WITH CHECK (
  (auth.role() = 'authenticated'::text) AND (
    -- Allow superusers
    (EXISTS (
      SELECT 1 FROM users
      WHERE supabase_id = (auth.uid())::text AND superuser = true
    )) OR
    -- Allow crew members to send messages
    (EXISTS (
      SELECT 1
      FROM crewmembers cm
      WHERE (cm.crew = messages.crew) AND (cm.crewmember = (auth.uid())::text)
    )) OR
    -- Allow problem originators to send messages on their problems
    (messages.problem IS NOT NULL AND EXISTS (
      SELECT 1
      FROM problem p
      WHERE (p.id = messages.problem) AND (p.originator = (auth.uid())::text)
    ))
  )
);

DROP POLICY IF EXISTS "messages_read_policy" ON "public"."messages";

CREATE POLICY "messages_read_policy"
ON "public"."messages"
AS PERMISSIVE
FOR SELECT
TO public
USING (
  (auth.role() = 'authenticated'::text) AND (
    -- Allow superusers
    (EXISTS (
      SELECT 1 FROM users
      WHERE supabase_id = (auth.uid())::text AND superuser = true
    )) OR
    -- Allow crew members to read messages
    (EXISTS (
      SELECT 1
      FROM crewmembers cm
      WHERE (cm.crew = messages.crew) AND (cm.crewmember = (auth.uid())::text)
    )) OR
    -- Allow problem originators to read messages on their problems
    (messages.problem IS NOT NULL AND EXISTS (
      SELECT 1
      FROM problem p
      WHERE (p.id = messages.problem) AND (p.originator = (auth.uid())::text)
    ))
  )
);
