-- SMS Simulator for testing
-- Stores simulated SMS messages for test phone numbers 2025551001-2025551005

CREATE TABLE IF NOT EXISTS public.sms_simulator (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  phone TEXT NOT NULL,  -- The simulated phone (2025551001-2025551005)
  direction TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),  -- inbound = to phone, outbound = from phone
  twilio_number TEXT NOT NULL,  -- The crew Twilio number
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sms_simulator_phone ON sms_simulator(phone);
CREATE INDEX idx_sms_simulator_created ON sms_simulator(created_at);

-- RLS: Only superusers can access
ALTER TABLE sms_simulator ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sms_simulator_superuser_all" ON sms_simulator
  FOR ALL TO authenticated
  USING (is_superuser(auth.uid()))
  WITH CHECK (is_superuser(auth.uid()));

-- Enable realtime for live updates
ALTER PUBLICATION supabase_realtime ADD TABLE sms_simulator;
