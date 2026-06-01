-- Pending crew members: let a crew chief invite someone (by email) to a crew before
-- that person has finished creating their account. The invite is held here and is
-- auto-converted into a real crewmembers row when the person completes signup.
-- (Startup-phase mechanism; see docs/superpowers/specs/2026-06-01-invite-crew-member-before-signup-design.md)

-- ============================================================================
-- 1. Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.pending_crewmembers (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  crew        bigint NOT NULL REFERENCES public.crews(id) ON DELETE CASCADE,
  email       text   NOT NULL,
  firstname   text,
  lastname    text,
  invited_by  text REFERENCES public.users(supabase_id),
  invited_at  timestamptz NOT NULL DEFAULT now()
);

-- One outstanding invite per (crew, email). Expression uniqueness needs an index.
CREATE UNIQUE INDEX IF NOT EXISTS pending_crewmembers_crew_email_uidx
  ON public.pending_crewmembers (crew, lower(email));

ALTER TABLE public.pending_crewmembers ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 2. RLS policies (mirror crew ownership)
-- ============================================================================
-- Insert: the crew's chief or a superuser.
CREATE POLICY "pending_crewmembers_insert_policy" ON public.pending_crewmembers
FOR INSERT WITH CHECK (
  is_superuser(auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.crews c
    WHERE c.id = pending_crewmembers.crew AND c.crew_chief = auth.uid()::text
  )
);

-- Delete (cancel invite): the crew's chief or a superuser.
CREATE POLICY "pending_crewmembers_delete_policy" ON public.pending_crewmembers
FOR DELETE USING (
  is_superuser(auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.crews c
    WHERE c.id = pending_crewmembers.crew AND c.crew_chief = auth.uid()::text
  )
);

-- Select (show in roster): crew members of the crew, the crew chief, or a superuser.
CREATE POLICY "pending_crewmembers_select_policy" ON public.pending_crewmembers
FOR SELECT USING (
  is_superuser(auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.crews c
    WHERE c.id = pending_crewmembers.crew AND c.crew_chief = auth.uid()::text
  )
  OR EXISTS (
    SELECT 1 FROM public.crewmembers cm
    WHERE cm.crew = pending_crewmembers.crew AND cm.crewmember = auth.uid()::text
  )
);

-- ============================================================================
-- 3. Reconciliation: when a users row is created, convert matching invites
-- ============================================================================
CREATE OR REPLACE FUNCTION public.reconcile_pending_crewmembers()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_email text;
BEGIN
  -- public.users has no email column; the email lives in auth.users.
  SELECT email INTO v_email FROM auth.users WHERE id = NEW.supabase_id::uuid;
  IF v_email IS NULL THEN
    RETURN NEW;
  END IF;

  -- Add the new user to every crew that invited their email (skip if already a member).
  INSERT INTO public.crewmembers (crew, crewmember)
  SELECT pc.crew, NEW.supabase_id
  FROM public.pending_crewmembers pc
  WHERE lower(pc.email) = lower(v_email)
    AND NOT EXISTS (
      SELECT 1 FROM public.crewmembers cm
      WHERE cm.crew = pc.crew AND cm.crewmember = NEW.supabase_id
    );

  -- Clear the now-fulfilled invites.
  DELETE FROM public.pending_crewmembers WHERE lower(email) = lower(v_email);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS reconcile_pending_crewmembers_trg ON public.users;
CREATE TRIGGER reconcile_pending_crewmembers_trg
AFTER INSERT ON public.users
FOR EACH ROW EXECUTE FUNCTION public.reconcile_pending_crewmembers();

-- ============================================================================
-- 4. invite_or_add_crewmember: the decision used by the invite-crew-member function.
--    If the email already belongs to a registered user, add them to the crew now;
--    otherwise record a pending invite. Returns 'added' or 'invited'.
--    (Authorization that the caller is the crew chief is enforced in the edge function.)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.invite_or_add_crewmember(
  p_crew      bigint,
  p_email     text,
  p_firstname text,
  p_lastname  text,
  p_invited_by text
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_email text := lower(btrim(p_email));
  v_uid   text;
BEGIN
  -- Already a registered user? (email lives in auth.users)
  SELECT u.supabase_id INTO v_uid
  FROM auth.users au
  JOIN public.users u ON u.supabase_id = au.id::text
  WHERE lower(au.email) = v_email
  LIMIT 1;

  IF v_uid IS NOT NULL THEN
    INSERT INTO public.crewmembers (crew, crewmember)
    SELECT p_crew, v_uid
    WHERE NOT EXISTS (
      SELECT 1 FROM public.crewmembers cm WHERE cm.crew = p_crew AND cm.crewmember = v_uid
    );
    RETURN 'added';
  END IF;

  INSERT INTO public.pending_crewmembers (crew, email, firstname, lastname, invited_by)
  VALUES (p_crew, v_email, p_firstname, p_lastname, p_invited_by)
  ON CONFLICT (crew, lower(email))
  DO UPDATE SET firstname  = EXCLUDED.firstname,
                lastname   = EXCLUDED.lastname,
                invited_by = EXCLUDED.invited_by,
                invited_at = now();
  RETURN 'invited';
END;
$$;
