-- Fix device_tokens RLS policy to allow inserts and deletes
-- The previous policy only had USING (for SELECT/UPDATE/DELETE reads)
-- but no WITH CHECK (needed for INSERT/UPDATE writes)

DROP POLICY IF EXISTS "device_tokens_policy" ON "public"."device_tokens";

CREATE POLICY "device_tokens_select"
ON "public"."device_tokens"
AS PERMISSIVE
FOR SELECT
TO public
USING ((user_id = (auth.uid())::text));

CREATE POLICY "device_tokens_insert"
ON "public"."device_tokens"
AS PERMISSIVE
FOR INSERT
TO public
WITH CHECK ((user_id = (auth.uid())::text));

CREATE POLICY "device_tokens_delete"
ON "public"."device_tokens"
AS PERMISSIVE
FOR DELETE
TO public
USING ((user_id = (auth.uid())::text));
