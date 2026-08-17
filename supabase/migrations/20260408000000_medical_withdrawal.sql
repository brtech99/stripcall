-- Medical Withdrawal Feature
-- Adds Bout Committee crew type, Medical Withdrawal symptom/actions,
-- medical_withdrawals table, and problem_notifications table.

-- ============================================================================
-- 1. Add receives_problems column to crewtypes
-- ============================================================================
ALTER TABLE public.crewtypes ADD COLUMN IF NOT EXISTS receives_problems boolean DEFAULT true;

-- ============================================================================
-- 2. Insert "Bout Committee" crew type (receives_problems = false)
-- ============================================================================
INSERT INTO public.crewtypes (crewtype, receives_problems)
SELECT 'Bout Committee', false
WHERE NOT EXISTS (
  SELECT 1 FROM public.crewtypes WHERE crewtype = 'Bout Committee'
);

-- ============================================================================
-- 3. Add "Medical Withdrawal" symptom class under Medical crew type
-- ============================================================================
INSERT INTO public.symptomclass (symptomclassstring, "crewType", display_order)
SELECT 'Medical Withdrawal', ct.id, 4
FROM public.crewtypes ct
WHERE ct.crewtype = 'Medical'
AND NOT EXISTS (
  SELECT 1 FROM public.symptomclass sc
  WHERE sc.symptomclassstring = 'Medical Withdrawal' AND sc."crewType" = ct.id
);

-- ============================================================================
-- 4. Add "Medical Withdrawal Request" symptom
-- ============================================================================
INSERT INTO public.symptom (symptomclass, symptomstring, display_order)
SELECT sc.id, 'Medical Withdrawal Request', 1
FROM public.symptomclass sc
JOIN public.crewtypes ct ON sc."crewType" = ct.id
WHERE sc.symptomclassstring = 'Medical Withdrawal' AND ct.crewtype = 'Medical'
AND NOT EXISTS (
  SELECT 1 FROM public.symptom s WHERE s.symptomclass = sc.id AND s.symptomstring = 'Medical Withdrawal Request'
);

-- ============================================================================
-- 5. Add resolution actions for Medical Withdrawal Request
-- ============================================================================
INSERT INTO public.action (symptom, actionstring, display_order)
SELECT s.id, unnest.actionstring, unnest.display_order
FROM public.symptom s
JOIN public.symptomclass sc ON s.symptomclass = sc.id
CROSS JOIN (VALUES
  ('Approved', 1),
  ('Not Approved', 2),
  ('Withdrawal Rescinded', 3)
) AS unnest(actionstring, display_order)
WHERE s.symptomstring = 'Medical Withdrawal Request'
AND sc.symptomclassstring = 'Medical Withdrawal'
AND NOT EXISTS (
  SELECT 1 FROM public.action a WHERE a.symptom = s.id AND a.actionstring = unnest.actionstring
);

-- ============================================================================
-- 6. Create BOTH tables first (before any RLS policies that cross-reference)
-- ============================================================================

-- 6a. medical_withdrawals table
CREATE TABLE IF NOT EXISTS public.medical_withdrawals (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  problem bigint NOT NULL REFERENCES public.problem(id),
  fencer_name text NOT NULL,
  membership_number text NOT NULL,
  event_name text NOT NULL,
  notes text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.medical_withdrawals ENABLE ROW LEVEL SECURITY;

-- 6b. problem_notifications table
CREATE TABLE IF NOT EXISTS public.problem_notifications (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  problem bigint NOT NULL REFERENCES public.problem(id),
  crew bigint NOT NULL REFERENCES public.crews(id),
  acknowledged_by text REFERENCES public.users(supabase_id),
  acknowledged_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.problem_notifications ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 7. RLS policies for medical_withdrawals
-- ============================================================================

-- Read: crew members of the problem's crew, superusers, or crew members of notified crews
CREATE POLICY "medical_withdrawals_read_policy" ON public.medical_withdrawals
FOR SELECT USING (
  is_superuser(auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.problem p
    JOIN public.crewmembers cm ON cm.crew = p.crew
    WHERE p.id = medical_withdrawals.problem
    AND cm.crewmember = auth.uid()::text
  )
  OR EXISTS (
    SELECT 1 FROM public.problem p
    JOIN public.crews c ON c.id = p.crew
    WHERE p.id = medical_withdrawals.problem
    AND c.crew_chief = auth.uid()::text
  )
  OR EXISTS (
    SELECT 1 FROM public.problem_notifications pn
    JOIN public.crewmembers cm ON cm.crew = pn.crew
    WHERE pn.problem = medical_withdrawals.problem
    AND cm.crewmember = auth.uid()::text
  )
  OR EXISTS (
    SELECT 1 FROM public.problem_notifications pn
    JOIN public.crews c ON c.id = pn.crew
    WHERE pn.problem = medical_withdrawals.problem
    AND c.crew_chief = auth.uid()::text
  )
);

-- Insert: authenticated users
CREATE POLICY "medical_withdrawals_insert_policy" ON public.medical_withdrawals
FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Update: crew members of the problem's crew or superusers
CREATE POLICY "medical_withdrawals_update_policy" ON public.medical_withdrawals
FOR UPDATE USING (
  is_superuser(auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.problem p
    JOIN public.crewmembers cm ON cm.crew = p.crew
    WHERE p.id = medical_withdrawals.problem
    AND cm.crewmember = auth.uid()::text
  )
  OR EXISTS (
    SELECT 1 FROM public.problem p
    JOIN public.crews c ON c.id = p.crew
    WHERE p.id = medical_withdrawals.problem
    AND c.crew_chief = auth.uid()::text
  )
);

-- ============================================================================
-- 8. RLS policies for problem_notifications
-- ============================================================================

-- Read: crew members/chiefs of the notified crew, or superusers
CREATE POLICY "problem_notifications_read_policy" ON public.problem_notifications
FOR SELECT USING (
  is_superuser(auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.crewmembers cm
    WHERE cm.crew = problem_notifications.crew
    AND cm.crewmember = auth.uid()::text
  )
  OR EXISTS (
    SELECT 1 FROM public.crews c
    WHERE c.id = problem_notifications.crew
    AND c.crew_chief = auth.uid()::text
  )
);

-- Insert: authenticated users
CREATE POLICY "problem_notifications_insert_policy" ON public.problem_notifications
FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Update: crew members/chiefs of the notified crew (for acknowledging)
CREATE POLICY "problem_notifications_update_policy" ON public.problem_notifications
FOR UPDATE USING (
  is_superuser(auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.crewmembers cm
    WHERE cm.crew = problem_notifications.crew
    AND cm.crewmember = auth.uid()::text
  )
  OR EXISTS (
    SELECT 1 FROM public.crews c
    WHERE c.id = problem_notifications.crew
    AND c.crew_chief = auth.uid()::text
  )
);
