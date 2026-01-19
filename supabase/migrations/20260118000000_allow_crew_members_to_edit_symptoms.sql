-- Allow any crew member (not just crew chiefs) to insert into oldproblemsymptom
-- This enables crew members to change the symptom on problems assigned to their crew

-- Drop the existing insert policy
DROP POLICY IF EXISTS "oldproblemsymptom_insert_policy" ON "public"."oldproblemsymptom";

-- Create new insert policy that allows:
-- 1. Superusers
-- 2. Any crew member of the crew the problem is assigned to
CREATE POLICY "oldproblemsymptom_insert_policy"
ON "public"."oldproblemsymptom"
AS PERMISSIVE
FOR INSERT
TO public
WITH CHECK (
  is_superuser(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM problem p
    JOIN crewmembers cm ON cm.crew = p.crew
    WHERE p.id = oldproblemsymptom.problem
    AND cm.crewmember = (auth.uid())::text
  )
);
