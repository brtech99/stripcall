-- SMS Bridge Schema Migration
-- Enables SMS-to-App bridge for legacy Twilio-based crew communication

-- 1. SMS reply slots (tracks +n assignments per crew, 1-4 rotating)
-- Each incoming message from a non-crew member gets assigned a +n slot
-- Crew members reply with "+n message" to route their reply to that problem/message
CREATE TABLE IF NOT EXISTS public.sms_reply_slots (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  crew_id BIGINT NOT NULL REFERENCES crews(id) ON DELETE CASCADE,
  slot SMALLINT NOT NULL CHECK (slot >= 1 AND slot <= 4),
  phone TEXT NOT NULL,  -- The non-crew reporter's phone
  problem_id BIGINT REFERENCES problem(id) ON DELETE SET NULL,
  message_id BIGINT,  -- The specific message this slot was assigned to (for context)
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours'),
  UNIQUE (crew_id, slot)
);

CREATE INDEX IF NOT EXISTS idx_sms_reply_slots_phone ON sms_reply_slots(phone);
CREATE INDEX IF NOT EXISTS idx_sms_reply_slots_expires ON sms_reply_slots(expires_at);
CREATE INDEX IF NOT EXISTS idx_sms_reply_slots_problem ON sms_reply_slots(problem_id);

-- Track the next slot number per crew (1-4, rotating)
CREATE TABLE IF NOT EXISTS public.sms_crew_slot_counter (
  crew_id BIGINT PRIMARY KEY REFERENCES crews(id) ON DELETE CASCADE,
  next_slot SMALLINT NOT NULL DEFAULT 1 CHECK (next_slot >= 1 AND next_slot <= 4)
);

ALTER TABLE sms_crew_slot_counter ENABLE ROW LEVEL SECURITY;

-- RLS: Service role only (edge functions use service role key)
ALTER TABLE sms_reply_slots ENABLE ROW LEVEL SECURITY;

-- 2. SMS reporters (referee names - imported from GCS or added manually)
CREATE TABLE IF NOT EXISTS public.sms_reporters (
  phone TEXT PRIMARY KEY,
  name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_reporters_name ON sms_reporters(name);

ALTER TABLE sms_reporters ENABLE ROW LEVEL SECURITY;

-- Allow superusers to read/write sms_reporters for management
CREATE POLICY "sms_reporters_superuser_all" ON sms_reporters
  FOR ALL TO authenticated
  USING (is_superuser(auth.uid()))
  WITH CHECK (is_superuser(auth.uid()));

-- 3. Add reporter_phone column to problem table for SMS-originated problems
ALTER TABLE problem ADD COLUMN IF NOT EXISTS reporter_phone TEXT;

CREATE INDEX IF NOT EXISTS idx_problem_reporter_phone
  ON problem(reporter_phone)
  WHERE reporter_phone IS NOT NULL;

COMMENT ON COLUMN problem.reporter_phone IS 'Phone number of SMS reporter (non-app user). Used for outbound SMS notifications.';

-- 4. Add "SMS Report - Needs Triage" symptom for each crew type
-- First ensure we have a General symptomclass for each crew type
DO $$
DECLARE
  crew_type_rec RECORD;
  general_class_id BIGINT;
BEGIN
  FOR crew_type_rec IN SELECT id, crewtype FROM crewtypes LOOP
    -- Check if General symptomclass exists for this crew type
    SELECT id INTO general_class_id
    FROM symptomclass
    WHERE symptomclassstring = 'General' AND "crewType" = crew_type_rec.id;

    -- If not, create it
    IF general_class_id IS NULL THEN
      INSERT INTO symptomclass (symptomclassstring, "crewType")
      VALUES ('General', crew_type_rec.id)
      RETURNING id INTO general_class_id;
    END IF;

    -- Add SMS symptom if it doesn't exist
    INSERT INTO symptom (symptomclass, symptomstring)
    SELECT general_class_id, 'SMS Report - Needs Triage'
    WHERE NOT EXISTS (
      SELECT 1 FROM symptom
      WHERE symptomclass = general_class_id
      AND symptomstring = 'SMS Report - Needs Triage'
    );
  END LOOP;
END $$;
