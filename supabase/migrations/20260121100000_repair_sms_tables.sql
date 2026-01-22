-- Repair migration: Create missing SMS bridge tables
-- The original migration may have partially failed

-- 1. Create sms_crew_slot_counter if it doesn't exist
CREATE TABLE IF NOT EXISTS public.sms_crew_slot_counter (
  crew_id BIGINT PRIMARY KEY REFERENCES crews(id) ON DELETE CASCADE,
  next_slot SMALLINT NOT NULL DEFAULT 1 CHECK (next_slot >= 1 AND next_slot <= 4)
);

ALTER TABLE sms_crew_slot_counter ENABLE ROW LEVEL SECURITY;

-- 2. Create sms_reply_slots if it doesn't exist
CREATE TABLE IF NOT EXISTS public.sms_reply_slots (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  crew_id BIGINT NOT NULL REFERENCES crews(id) ON DELETE CASCADE,
  slot SMALLINT NOT NULL CHECK (slot >= 1 AND slot <= 4),
  phone TEXT NOT NULL,
  problem_id BIGINT REFERENCES problem(id) ON DELETE SET NULL,
  message_id BIGINT,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours'),
  UNIQUE (crew_id, slot)
);

CREATE INDEX IF NOT EXISTS idx_sms_reply_slots_phone ON sms_reply_slots(phone);
CREATE INDEX IF NOT EXISTS idx_sms_reply_slots_expires ON sms_reply_slots(expires_at);
CREATE INDEX IF NOT EXISTS idx_sms_reply_slots_problem ON sms_reply_slots(problem_id);

ALTER TABLE sms_reply_slots ENABLE ROW LEVEL SECURITY;

-- 3. Ensure reporter_phone column exists on problem table
ALTER TABLE problem ADD COLUMN IF NOT EXISTS reporter_phone TEXT;

CREATE INDEX IF NOT EXISTS idx_problem_reporter_phone
  ON problem(reporter_phone)
  WHERE reporter_phone IS NOT NULL;
