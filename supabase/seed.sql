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
  confirmation_token,
  email_change,
  email_change_token_new,
  email_change_token_current,
  recovery_token,
  reauthentication_token
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
    '',
    '',
    '',
    '',
    '',
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
    '',
    '',
    '',
    '',
    '',
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
    '',
    '',
    '',
    '',
    '',
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
    '',
    '',
    '',
    '',
    '',
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
    '',
    '',
    '',
    '',
    '',
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
    '',
    '',
    '',
    '',
    '',
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
-- Phone numbers use SMS simulator numbers (2025551001-2025551004) for E2E testing
-- SimPhone.phone5 (2025551005) is RESERVED for dynamically created test users (e.g., Referee2)
-- Mapping: x1001=Armorer1, x1002=Armorer2, x1003=Medical1, x1004=Medical2, x1005=Referee2 (created in test)
-- is_sms_mode=true for crew members so they receive SMS notifications
INSERT INTO public.users (supabase_id, firstname, lastname, phonenbr, superuser, organizer, is_sms_mode) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Super', 'User', '5550000001', true, true, false),
  ('a0000000-0000-0000-0000-000000000002', 'Armorer', 'One', '2025551001', false, false, true),
  ('a0000000-0000-0000-0000-000000000003', 'Armorer', 'Two', '2025551002', false, false, true),
  ('a0000000-0000-0000-0000-000000000004', 'Medical', 'One', '2025551003', false, false, true),
  ('a0000000-0000-0000-0000-000000000005', 'Medical', 'Two', '2025551004', false, false, true),
  ('a0000000-0000-0000-0000-000000000006', 'Referee', 'One', '5550000006', false, false, false);

-- ============================================================================
-- CREW TYPES
-- ============================================================================
INSERT INTO public.crewtypes (crewtype) VALUES
  ('Armorer'),
  ('Medical'),
  ('Natloff');

-- ============================================================================
-- SYMPTOM CLASSES (linked to crew types)
-- ============================================================================
-- Get crew type IDs (Armorer=1, Medical=2 based on insert order)
INSERT INTO public.symptomclass (symptomclassstring, "crewType", display_order) VALUES
  -- Armorer symptom classes
  ('Weapon Issue', 1, 1),
  ('Scoring Equipment', 1, 2),
  ('Electrical', 1, 3),
  ('General', 1, 99),  -- For SMS Report - Needs Triage
  -- Medical symptom classes
  ('Injury', 2, 1),
  ('Illness', 2, 2),
  ('Head', 2, 3),      -- For Concussion symptom
  ('General', 2, 99),  -- For SMS Report - Needs Triage
  -- Natloff symptom classes
  ('Rules Violation', 3, 1),
  ('Card Issue', 3, 2),
  ('General', 3, 99);  -- For SMS Report - Needs Triage

-- ============================================================================
-- SYMPTOMS (linked to symptom classes)
-- ============================================================================
-- Symptom class IDs after insert:
--   1=Weapon Issue, 2=Scoring Equipment, 3=Electrical, 4=General(Armorer)
--   5=Injury, 6=Illness, 7=Head, 8=General(Medical)
--   9=Rules Violation, 10=Card Issue, 11=General(Natloff)
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
  -- General (Armorer) symptoms (symptomclass=4)
  (4, 'SMS Report - Needs Triage', 1),
  (4, 'Other', 99),
  -- Injury symptoms (symptomclass=5)
  (5, 'Cut/Laceration', 1),
  (5, 'Sprain/Strain', 2),
  (5, 'Head injury', 3),
  -- Illness symptoms (symptomclass=6)
  (6, 'Feeling faint', 1),
  (6, 'Dehydration', 2),
  (6, 'Nausea', 3),
  -- Head symptoms (symptomclass=7)
  (7, 'Concussion', 1),
  (7, 'Laceration to head', 2),
  -- General (Medical) symptoms (symptomclass=8)
  (8, 'SMS Report - Needs Triage', 1),
  (8, 'Other', 99),
  -- Rules Violation symptoms (symptomclass=9)
  (9, 'Black card', 1),
  (9, 'Red card', 2),
  (9, 'Yellow card', 3),
  -- Card Issue symptoms (symptomclass=10)
  (10, 'Missing card', 1),
  (10, 'Expired card', 2),
  -- General (Natloff) symptoms (symptomclass=11)
  (11, 'SMS Report - Needs Triage', 1),
  (11, 'Other', 99);

-- ============================================================================
-- ACTIONS (linked to symptoms for resolution)
-- ============================================================================
-- Symptom IDs after insert:
--   1=Blade broken, 2=Point not registering, 3=Guard loose
--   4=Reel not retracting, 5=Floor cord damaged, 6=Scoring box malfunction
--   7=Light not working, 8=Power issue
--   9=SMS Report - Needs Triage (Armorer), 10=Other (Armorer)
--   11=Cut/Laceration, 12=Sprain/Strain, 13=Head injury
--   14=Feeling faint, 15=Dehydration, 16=Nausea
--   17=Concussion, 18=Laceration to head
--   19=SMS Report - Needs Triage (Medical), 20=Other (Medical)
--   21=Black card, 22=Red card, 23=Yellow card
--   24=Missing card, 25=Expired card
--   26=SMS Report - Needs Triage (Natloff), 27=Other (Natloff)
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
  -- Actions for SMS Report - Needs Triage (Armorer) (symptom=9)
  (9, 'Triaged and resolved', 1),
  (9, 'Reclassified problem', 2),
  -- Actions for Other (Armorer) (symptom=10)
  (10, 'Resolved', 1),
  (10, 'Other', 99),
  -- Actions for Cut/Laceration (symptom=11)
  (11, 'Bandaged wound', 1),
  (11, 'Applied pressure', 2),
  (11, 'Referred to ER', 3),
  -- Actions for Sprain/Strain (symptom=12)
  (12, 'Applied ice', 1),
  (12, 'Wrapped injury', 2),
  (12, 'Referred to ER', 3),
  -- Actions for Head injury (symptom=13)
  (13, 'Assessed for concussion', 1),
  (13, 'Applied ice', 2),
  (13, 'Referred to ER', 3),
  -- Actions for Feeling faint (symptom=14)
  (14, 'Provided rest area', 1),
  (14, 'Gave fluids', 2),
  -- Actions for Dehydration (symptom=15)
  (15, 'Provided water', 1),
  (15, 'Provided electrolytes', 2),
  -- Actions for Nausea (symptom=16)
  (16, 'Provided rest area', 1),
  (16, 'Monitored condition', 2),
  -- Actions for Concussion (symptom=17)
  (17, 'Ran Concussion Protocol', 1),
  (17, 'Referred to ER', 2),
  (17, 'Cleared to continue', 3),
  -- Actions for Laceration to head (symptom=18)
  (18, 'Bandaged wound', 1),
  (18, 'Referred to ER', 2),
  -- Actions for SMS Report - Needs Triage (Medical) (symptom=19)
  (19, 'Triaged and resolved', 1),
  (19, 'Reclassified problem', 2),
  -- Actions for Other (Medical) (symptom=20)
  (20, 'Resolved', 1),
  (20, 'Other', 99),
  -- Actions for Black card (symptom=21)
  (21, 'Card issued', 1),
  (21, 'Referred to committee', 2),
  -- Actions for Red card (symptom=22)
  (22, 'Card issued', 1),
  (22, 'Referred to committee', 2),
  -- Actions for Yellow card (symptom=23)
  (23, 'Card issued', 1),
  -- Actions for Missing card (symptom=24)
  (24, 'Issued temporary card', 1),
  (24, 'Resolved', 2),
  -- Actions for Expired card (symptom=25)
  (25, 'Issued temporary card', 1),
  (25, 'Resolved', 2),
  -- Actions for SMS Report - Needs Triage (Natloff) (symptom=26)
  (26, 'Triaged and resolved', 1),
  (26, 'Reclassified problem', 2),
  -- Actions for Other (Natloff) (symptom=27)
  (27, 'Resolved', 1),
  (27, 'Other', 99);

-- ============================================================================
-- PRE-CONFIGURED EVENT FOR E2E TESTING
-- ============================================================================
-- Create a test event that's ready to use
INSERT INTO public.events (name, city, state, startdatetime, enddatetime, count, organizer)
VALUES (
  'E2E Test Event',
  'Test City',
  'TS',
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP + INTERVAL '3 days',
  20,
  'a0000000-0000-0000-0000-000000000001'  -- owned by superuser
);

-- Get the event ID (will be 1 since it's first insert)
-- Create Armorer crew for the event with armorer1 as chief
INSERT INTO public.crews (event, crew_type, crew_chief)
VALUES (
  1,  -- event ID
  1,  -- Armorer crew type
  'a0000000-0000-0000-0000-000000000002'  -- Armorer One is chief
);

-- Create Medical crew for the event with medical1 as chief
INSERT INTO public.crews (event, crew_type, crew_chief)
VALUES (
  1,  -- event ID
  2,  -- Medical crew type
  'a0000000-0000-0000-0000-000000000004'  -- Medical One is chief
);

-- Add crew members (chiefs are already part of crew via crew_chief)
-- Armorer crew (crew ID 1): add armorer2 as additional member
INSERT INTO public.crewmembers (crew, crewmember) VALUES
  (1, 'a0000000-0000-0000-0000-000000000003');  -- Armorer Two is member

-- Medical crew (crew ID 2): add medical2 as additional member
INSERT INTO public.crewmembers (crew, crewmember) VALUES
  (2, 'a0000000-0000-0000-0000-000000000005');  -- Medical Two is member

-- ============================================================================
-- TEST USER CREDENTIALS REFERENCE
-- ============================================================================
-- Email                      | Password          | Role                | Sim Phone
-- ---------------------------|-------------------|---------------------|----------
-- e2e_superuser@test.com     | TestPassword123!  | Superuser+Organizer | (none)
-- e2e_armorer1@test.com      | TestPassword123!  | Armorer crew chief  | 2025551001
-- e2e_armorer2@test.com      | TestPassword123!  | Armorer crew member | 2025551002
-- e2e_medical1@test.com      | TestPassword123!  | Medical crew chief  | 2025551003
-- e2e_medical2@test.com      | TestPassword123!  | Medical crew member | 2025551004
-- e2e_referee1@test.com      | TestPassword123!  | Referee (no crew)   | (none)
-- ============================================================================
--
-- CREW TYPES: Armorer=1, Medical=2, Natloff=3
--
-- SMS SIMULATOR PHONE MAPPING:
-- SimPhone.phone1 (2025551001) -> Armorer One (crew chief)
-- SimPhone.phone2 (2025551002) -> Armorer Two (crew member)
-- SimPhone.phone3 (2025551003) -> Medical One (crew chief)
-- SimPhone.phone4 (2025551004) -> Medical Two (crew member)
-- SimPhone.phone5 (2025551005) -> Referee Two (created in test, not seeded)
-- ============================================================================
