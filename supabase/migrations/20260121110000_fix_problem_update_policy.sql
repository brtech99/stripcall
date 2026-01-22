-- Fix problem update policy to allow crew members to edit problems for their crew
-- Currently only superusers, crew chiefs, and originators can edit

DROP POLICY IF EXISTS "problem_update_policy" ON "public"."problem";

CREATE POLICY "problem_update_policy"
ON "public"."problem"
AS PERMISSIVE
FOR UPDATE
TO public
USING (
  is_superuser(auth.uid())
  OR is_crew_chief(auth.uid(), crew)
  OR (originator = (auth.uid())::text)
  OR (EXISTS (
    SELECT 1 FROM crewmembers cm
    WHERE cm.crew = problem.crew
    AND cm.crewmember = (auth.uid())::text
  ))
);
