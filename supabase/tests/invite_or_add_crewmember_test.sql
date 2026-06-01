-- Test: invite_or_add_crewmember(crew, email, firstname, lastname, invited_by)
--   - If the email already belongs to a registered user -> add them to the crew now,
--     return 'added', create no pending row.
--   - Otherwise -> record a pending invite, return 'invited'.
-- Run: docker exec -i supabase_db_stripcall psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
--        < supabase/tests/invite_or_add_crewmember_test.sql

-- ----------------------------------------------------------------------------
-- Test A: unknown email -> 'invited', pending row created, no crewmember.
-- ----------------------------------------------------------------------------
BEGIN;
DO $$
DECLARE result text;
BEGIN
  result := public.invite_or_add_crewmember(1, 'Newbie@Example.com ', 'New', 'Bie', NULL);
  IF result <> 'invited' THEN
    RAISE EXCEPTION 'FAIL: expected ''invited'', got %', result;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.pending_crewmembers WHERE crew = 1 AND email = 'newbie@example.com') THEN
    RAISE EXCEPTION 'FAIL: pending invite not created (or email not normalized)';
  END IF;
  RAISE NOTICE 'PASS A: unknown email recorded as pending invite (normalized)';
END $$;
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Test B: known email (seeded Referee One, not on any crew) -> 'added' to crew 1.
-- ----------------------------------------------------------------------------
BEGIN;
DO $$
DECLARE result text;
BEGIN
  result := public.invite_or_add_crewmember(1, 'e2e_referee1@test.com', 'Referee', 'One', NULL);
  IF result <> 'added' THEN
    RAISE EXCEPTION 'FAIL: expected ''added'', got %', result;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.crewmembers
    WHERE crew = 1 AND crewmember = 'a0000000-0000-0000-0000-000000000006'
  ) THEN
    RAISE EXCEPTION 'FAIL: existing user was not added to the crew';
  END IF;
  IF EXISTS (SELECT 1 FROM public.pending_crewmembers WHERE crew = 1 AND email = 'e2e_referee1@test.com') THEN
    RAISE EXCEPTION 'FAIL: should not create a pending invite for an existing user';
  END IF;
  RAISE NOTICE 'PASS B: existing user added to crew directly';
END $$;
ROLLBACK;
