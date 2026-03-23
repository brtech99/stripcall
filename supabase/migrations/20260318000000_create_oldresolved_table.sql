-- Create oldresolved table to track when problems are unresolved
-- Mirrors the oldproblemsymptom pattern: records the previous resolution
-- before it is cleared, so we can analyze premature resolutions.

CREATE TABLE IF NOT EXISTS public.oldresolved (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  problem bigint NOT NULL,
  oldaction bigint,
  oldactionby text,
  oldenddatetime timestamp with time zone,
  unresolvedby text NOT NULL,
  unresolvedat timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT oldresolved_pkey PRIMARY KEY (id),
  CONSTRAINT oldresolved_problem_fkey FOREIGN KEY (problem) REFERENCES public.problem(id),
  CONSTRAINT oldresolved_oldaction_fkey FOREIGN KEY (oldaction) REFERENCES public.action(id),
  CONSTRAINT oldresolved_oldactionby_fkey FOREIGN KEY (oldactionby) REFERENCES public.users(supabase_id),
  CONSTRAINT oldresolved_unresolvedby_fkey FOREIGN KEY (unresolvedby) REFERENCES public.users(supabase_id)
);

ALTER TABLE public.oldresolved ENABLE ROW LEVEL SECURITY;

-- Read: any authenticated user
CREATE POLICY "oldresolved_read_policy"
ON "public"."oldresolved"
AS PERMISSIVE
FOR SELECT
TO public
USING ((auth.role() = 'authenticated'::text));

-- Insert: superusers or crew members of the problem's crew
CREATE POLICY "oldresolved_insert_policy"
ON "public"."oldresolved"
AS PERMISSIVE
FOR INSERT
TO public
WITH CHECK (
  is_superuser(auth.uid())
  OR EXISTS (
    SELECT 1
    FROM problem p
    JOIN crewmembers cm ON cm.crew = p.crew
    WHERE p.id = oldresolved.problem
    AND cm.crewmember = (auth.uid())::text
  )
);

-- Update/Delete: superusers only
CREATE POLICY "oldresolved_update_policy"
ON "public"."oldresolved"
AS PERMISSIVE
FOR UPDATE
TO public
USING (((auth.role() = 'authenticated'::text) AND is_superuser(auth.uid())))
WITH CHECK (((auth.role() = 'authenticated'::text) AND is_superuser(auth.uid())));

CREATE POLICY "oldresolved_delete_policy"
ON "public"."oldresolved"
AS PERMISSIVE
FOR DELETE
TO public
USING (((auth.role() = 'authenticated'::text) AND is_superuser(auth.uid())));
