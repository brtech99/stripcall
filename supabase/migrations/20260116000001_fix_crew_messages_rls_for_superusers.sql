-- Fix crew_messages RLS policy to allow superusers to send messages

DROP POLICY IF EXISTS "Users can insert crew messages for their crews" ON "public"."crew_messages";

CREATE POLICY "Users can insert crew messages for their crews"
ON "public"."crew_messages"
AS PERMISSIVE
FOR INSERT
TO public
WITH CHECK (
  -- Allow superusers
  (EXISTS (
    SELECT 1 FROM users
    WHERE supabase_id = (auth.uid())::text AND superuser = true
  )) OR
  -- Allow crew members
  (EXISTS (
    SELECT 1 FROM crewmembers
    WHERE crewmembers.crew = crew_messages.crew
    AND crewmembers.crewmember = (auth.uid())::text
  ))
);

DROP POLICY IF EXISTS "Users can view crew messages for their crews" ON "public"."crew_messages";

CREATE POLICY "Users can view crew messages for their crews"
ON "public"."crew_messages"
AS PERMISSIVE
FOR SELECT
TO public
USING (
  -- Allow superusers
  (EXISTS (
    SELECT 1 FROM users
    WHERE supabase_id = (auth.uid())::text AND superuser = true
  )) OR
  -- Allow crew members
  (EXISTS (
    SELECT 1 FROM crewmembers
    WHERE crewmembers.crew = crew_messages.crew
    AND crewmembers.crewmember = (auth.uid())::text
  ))
);
