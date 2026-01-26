-- Seed file for E2E testing (local Supabase only)
-- Run with: supabase db reset (applies migrations then runs this seed)

-- ============================================================================
-- TEST USERS (6 total)
-- Password for all: TestPassword123!
-- ============================================================================

-- The password hash below is for 'TestPassword123!' using bcrypt
-- Generated for local testing only

-- Insert auth users
INSERT INTO auth.users (
  id,
  instance_id,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  role,
  aud,
  confirmation_token
) VALUES
  -- e2e_superuser@test.com
  (
    'a0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'e2e_superuser@test.com',
    '$2a$10$nsE0k.DIV9X.AqHCIR7EK.VNO9nMIIZy1PaTLLqV6gWo7Q9PZAnMq',
    now(),
    now(),
    now(),
    '{"provider": "email", "providers": ["email"]}',
    '{"firstname": "Super", "lastname": "User"}',
    false,
    'authenticated',
    'authenticated',
    ''
  ),
  -- e2e_armorer1@test.com (will be Armorer crew chief)
  (
    'a0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'e2e_armorer1@test.com',
    '$2a$10$nsE0k.DIV9X.AqHCIR7EK.VNO9nMIIZy1PaTLLqV6gWo7Q9PZAnMq',
    now(),
    now(),
    now(),
    '{"provider": "email", "providers": ["email"]}',
    '{"firstname": "Armorer", "lastname": "One"}',
    false,
    'authenticated',
    'authenticated',
    ''
  ),
  -- e2e_armorer2@test.com (will be Armorer crew member)
  (
    'a0000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000000',
    'e2e_armorer2@test.com',
    '$2a$10$nsE0k.DIV9X.AqHCIR7EK.VNO9nMIIZy1PaTLLqV6gWo7Q9PZAnMq',
    now(),
    now(),
    now(),
    '{"provider": "email", "providers": ["email"]}',
    '{"firstname": "Armorer", "lastname": "Two"}',
    false,
    'authenticated',
    'authenticated',
    ''
  ),
  -- e2e_medical1@test.com (will be Medical crew chief)
  (
    'a0000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000000',
    'e2e_medical1@test.com',
    '$2a$10$nsE0k.DIV9X.AqHCIR7EK.VNO9nMIIZy1PaTLLqV6gWo7Q9PZAnMq',
    now(),
    now(),
    now(),
    '{"provider": "email", "providers": ["email"]}',
    '{"firstname": "Medical", "lastname": "One"}',
    false,
    'authenticated',
    'authenticated',
    ''
  ),
  -- e2e_medical2@test.com (will be Medical crew member)
  (
    'a0000000-0000-0000-0000-000000000005',
    '00000000-0000-0000-0000-000000000000',
    'e2e_medical2@test.com',
    '$2a$10$nsE0k.DIV9X.AqHCIR7EK.VNO9nMIIZy1PaTLLqV6gWo7Q9PZAnMq',
    now(),
    now(),
    now(),
    '{"provider": "email", "providers": ["email"]}',
    '{"firstname": "Medical", "lastname": "Two"}',
    false,
    'authenticated',
    'authenticated',
    ''
  ),
  -- e2e_referee1@test.com (referee - no crew)
  (
    'a0000000-0000-0000-0000-000000000006',
    '00000000-0000-0000-0000-000000000000',
    'e2e_referee1@test.com',
    '$2a$10$nsE0k.DIV9X.AqHCIR7EK.VNO9nMIIZy1PaTLLqV6gWo7Q9PZAnMq',
    now(),
    now(),
    now(),
    '{"provider": "email", "providers": ["email"]}',
    '{"firstname": "Referee", "lastname": "One"}',
    false,
    'authenticated',
    'authenticated',
    ''
  );

-- Insert identities for each user (required for auth to work)
INSERT INTO auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  created_at,
  updated_at,
  last_sign_in_at
) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', '{"sub": "a0000000-0000-0000-0000-000000000001", "email": "e2e_superuser@test.com"}', 'email', 'a0000000-0000-0000-0000-000000000001', now(), now(), now()),
  ('a0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', '{"sub": "a0000000-0000-0000-0000-000000000002", "email": "e2e_armorer1@test.com"}', 'email', 'a0000000-0000-0000-0000-000000000002', now(), now(), now()),
  ('a0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000003', '{"sub": "a0000000-0000-0000-0000-000000000003", "email": "e2e_armorer2@test.com"}', 'email', 'a0000000-0000-0000-0000-000000000003', now(), now(), now()),
  ('a0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000004', '{"sub": "a0000000-0000-0000-0000-000000000004", "email": "e2e_medical1@test.com"}', 'email', 'a0000000-0000-0000-0000-000000000004', now(), now(), now()),
  ('a0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000005', '{"sub": "a0000000-0000-0000-0000-000000000005", "email": "e2e_medical2@test.com"}', 'email', 'a0000000-0000-0000-0000-000000000005', now(), now(), now()),
  ('a0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000006', '{"sub": "a0000000-0000-0000-0000-000000000006", "email": "e2e_referee1@test.com"}', 'email', 'a0000000-0000-0000-0000-000000000006', now(), now(), now());

-- Insert into public.users table
INSERT INTO public.users (supabase_id, firstname, lastname, phonenbr, superuser, organizer) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Super', 'User', '555-000-0001', true, true),
  ('a0000000-0000-0000-0000-000000000002', 'Armorer', 'One', '555-000-0002', false, false),
  ('a0000000-0000-0000-0000-000000000003', 'Armorer', 'Two', '555-000-0003', false, false),
  ('a0000000-0000-0000-0000-000000000004', 'Medical', 'One', '555-000-0004', false, false),
  ('a0000000-0000-0000-0000-000000000005', 'Medical', 'Two', '555-000-0005', false, false),
  ('a0000000-0000-0000-0000-000000000006', 'Referee', 'One', '555-000-0006', false, false);

-- ============================================================================
-- CREW TYPES
-- ============================================================================
INSERT INTO public.crewtypes (crewtype) VALUES
  ('Armorer'),
  ('Medical');

-- ============================================================================
-- SYMPTOM CLASSES (linked to crew types)
-- ============================================================================
-- Get crew type IDs (Armorer=1, Medical=2 based on insert order)
INSERT INTO public.symptomclass (symptomclassstring, "crewType", display_order) VALUES
  -- Armorer symptom classes
  ('Weapon Issue', 1, 1),
  ('Scoring Equipment', 1, 2),
  ('Electrical', 1, 3),
  -- Medical symptom classes
  ('Injury', 2, 1),
  ('Illness', 2, 2);

-- ============================================================================
-- SYMPTOMS (linked to symptom classes)
-- ============================================================================
INSERT INTO public.symptom (symptomclass, symptomstring, display_order) VALUES
  -- Weapon Issue symptoms (symptomclass=1)
  (1, 'Blade broken', 1),
  (1, 'Point not registering', 2),
  (1, 'Guard loose', 3),
  -- Scoring Equipment symptoms (symptomclass=2)
  (2, 'Reel not retracting', 1),
  (2, 'Floor cord damaged', 2),
  (2, 'Scoring box malfunction', 3),
  -- Electrical symptoms (symptomclass=3)
  (3, 'Light not working', 1),
  (3, 'Power issue', 2),
  -- Injury symptoms (symptomclass=4)
  (4, 'Cut/Laceration', 1),
  (4, 'Sprain/Strain', 2),
  (4, 'Head injury', 3),
  -- Illness symptoms (symptomclass=5)
  (5, 'Feeling faint', 1),
  (5, 'Dehydration', 2),
  (5, 'Nausea', 3);

-- ============================================================================
-- ACTIONS (linked to symptoms for resolution)
-- ============================================================================
INSERT INTO public.action (symptom, actionstring, display_order) VALUES
  -- Actions for Blade broken (symptom=1)
  (1, 'Replaced blade', 1),
  (1, 'Repaired blade', 2),
  (1, 'Fencer provided replacement', 3),
  -- Actions for Point not registering (symptom=2)
  (2, 'Cleaned point', 1),
  (2, 'Replaced point', 2),
  (2, 'Adjusted spring tension', 3),
  -- Actions for Guard loose (symptom=3)
  (3, 'Tightened guard', 1),
  (3, 'Replaced pommel', 2),
  -- Actions for Reel not retracting (symptom=4)
  (4, 'Replaced reel', 1),
  (4, 'Lubricated reel', 2),
  -- Actions for Floor cord damaged (symptom=5)
  (5, 'Replaced floor cord', 1),
  (5, 'Repaired connection', 2),
  -- Actions for Scoring box malfunction (symptom=6)
  (6, 'Replaced scoring box', 1),
  (6, 'Reset scoring box', 2),
  -- Actions for Light not working (symptom=7)
  (7, 'Replaced bulb', 1),
  (7, 'Fixed wiring', 2),
  -- Actions for Power issue (symptom=8)
  (8, 'Reset breaker', 1),
  (8, 'Replaced power strip', 2),
  -- Actions for Cut/Laceration (symptom=9)
  (9, 'Bandaged wound', 1),
  (9, 'Applied pressure', 2),
  (9, 'Referred to ER', 3),
  -- Actions for Sprain/Strain (symptom=10)
  (10, 'Applied ice', 1),
  (10, 'Wrapped injury', 2),
  (10, 'Referred to ER', 3),
  -- Actions for Head injury (symptom=11)
  (11, 'Assessed for concussion', 1),
  (11, 'Applied ice', 2),
  (11, 'Referred to ER', 3),
  -- Actions for Feeling faint (symptom=12)
  (12, 'Provided rest area', 1),
  (12, 'Gave fluids', 2),
  -- Actions for Dehydration (symptom=13)
  (13, 'Provided water', 1),
  (13, 'Provided electrolytes', 2),
  -- Actions for Nausea (symptom=14)
  (14, 'Provided rest area', 1),
  (14, 'Monitored condition', 2);

-- ============================================================================
-- TEST USER CREDENTIALS REFERENCE
-- ============================================================================
-- Email                      | Password          | Role
-- ---------------------------|-------------------|---------------------------
-- e2e_superuser@test.com     | TestPassword123!  | Superuser + Organizer
-- e2e_armorer1@test.com      | TestPassword123!  | Will be Armorer crew chief
-- e2e_armorer2@test.com      | TestPassword123!  | Will be Armorer crew member
-- e2e_medical1@test.com      | TestPassword123!  | Will be Medical crew chief
-- e2e_medical2@test.com      | TestPassword123!  | Will be Medical crew member
-- e2e_referee1@test.com      | TestPassword123!  | Referee (no crew)
-- ============================================================================
