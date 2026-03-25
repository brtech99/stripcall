-- Table for phone OTP codes during account signup (unauthenticated flow).
-- Separate from phone_otp_codes which requires an authenticated user.

CREATE TABLE IF NOT EXISTS public.signup_otp_codes (
  id SERIAL PRIMARY KEY,
  phone TEXT NOT NULL,
  email TEXT NOT NULL,
  code TEXT NOT NULL,
  attempts INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ DEFAULT (now() + interval '10 minutes'),
  verified_at TIMESTAMPTZ
);

-- Index for lookups
CREATE INDEX idx_signup_otp_phone_email ON public.signup_otp_codes (phone, email);

-- RLS: only service role can access (edge functions use service role key)
ALTER TABLE public.signup_otp_codes ENABLE ROW LEVEL SECURITY;

-- Auto-cleanup: delete expired codes older than 1 hour
-- (handled by edge function on each call)
