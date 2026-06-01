-- Test: a pending crew invite is auto-converted into a real crewmembers row when the
-- invited person completes signup (a public.users row is created with the matching email),
-- and the pending row is cleared.
--
-- Run: docker exec -i supabase_db_stripcall psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
--        < supabase/tests/pending_crewmembers_test.sql
-- Wrapped in a transaction that always rolls back, so it leaves no residue.

BEGIN;

\set uid '11111111-2222-3333-4444-555555555555'
\set email 'invitee@example.com'

-- Arrange: chief invites invitee@example.com to crew 1 (Armorer, E2E Test Event)
INSERT INTO public.pending_crewmembers (crew, email, firstname, lastname)
VALUES (1, :'email', 'In', 'Vitee');

-- Act: invitee completes signup -> auth.users + public.users rows with that email
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
  is_super_admin, role, aud, confirmation_token, email_change,
  email_change_token_new, email_change_token_current, recovery_token,
  reauthentication_token
) VALUES (
  :'uid', '00000000-0000-0000-0000-000000000000', :'email',
  '$2a$10$abcdefghijklmnopqrstuv', now(), now(), now(),
  '{"provider":"email","providers":["email"]}', '{"firstname":"In","lastname":"Vitee"}',
  false, 'authenticated', 'authenticated', '', '', '', '', '', ''
);

INSERT INTO public.users (supabase_id, firstname, lastname, phonenbr, superuser, organizer, is_sms_mode)
VALUES (:'uid', 'In', 'Vitee', NULL, false, false, false);

-- Assert
DO $$
DECLARE v_uid text := '11111111-2222-3333-4444-555555555555';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.crewmembers WHERE crew = 1 AND crewmember = v_uid) THEN
    RAISE EXCEPTION 'FAIL: expected crewmembers row (crew=1, crewmember=%) was not created', v_uid;
  END IF;
  IF EXISTS (SELECT 1 FROM public.pending_crewmembers WHERE crew = 1 AND lower(email) = 'invitee@example.com') THEN
    RAISE EXCEPTION 'FAIL: pending_crewmembers row was not cleared after signup';
  END IF;
  RAISE NOTICE 'PASS: pending invite reconciled into crewmembers and cleared';
END $$;

ROLLBACK;

-- ----------------------------------------------------------------------------
-- Test 2: signing up with a DIFFERENT email must NOT reconcile the invite.
-- ----------------------------------------------------------------------------
BEGIN;
INSERT INTO public.pending_crewmembers (crew, email) VALUES (1, 'invited@example.com');
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data, is_super_admin, role, aud,
  confirmation_token, email_change, email_change_token_new, email_change_token_current,
  recovery_token, reauthentication_token
) VALUES (
  '22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000',
  'someone-else@example.com', '$2a$10$abcdefghijklmnopqrstuv', now(), now(), now(),
  '{"provider":"email","providers":["email"]}', '{}', false, 'authenticated', 'authenticated',
  '', '', '', '', '', ''
);
INSERT INTO public.users (supabase_id, firstname, lastname, superuser, organizer, is_sms_mode)
VALUES ('22222222-2222-2222-2222-222222222222', 'Some', 'Else', false, false, false);
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.crewmembers WHERE crew = 1 AND crewmember = '22222222-2222-2222-2222-222222222222') THEN
    RAISE EXCEPTION 'FAIL: a mismatched email should not have been added to the crew';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.pending_crewmembers WHERE crew = 1 AND lower(email) = 'invited@example.com') THEN
    RAISE EXCEPTION 'FAIL: invite for a different email should remain pending';
  END IF;
  RAISE NOTICE 'PASS: mismatched-email signup left the invite untouched';
END $$;
ROLLBACK;
