-- Phone OTP codes for phone number verification
CREATE TABLE IF NOT EXISTS phone_otp_codes (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  phone TEXT NOT NULL,
  code TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '10 minutes'),
  verified_at TIMESTAMPTZ,
  attempts INT DEFAULT 0
);

-- Index for looking up codes
CREATE INDEX idx_phone_otp_codes_user_phone ON phone_otp_codes(user_id, phone);
CREATE INDEX idx_phone_otp_codes_expires ON phone_otp_codes(expires_at);

-- RLS: Service role only (edge functions)
ALTER TABLE phone_otp_codes ENABLE ROW LEVEL SECURITY;

-- Cleanup old OTP codes (can be run periodically)
-- DELETE FROM phone_otp_codes WHERE expires_at < NOW();
