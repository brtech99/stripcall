-- Make phone_number nullable in pending_users.
-- Phone is now optional during account creation and gets added
-- after OTP verification via the verify-signup-otp edge function.

ALTER TABLE public.pending_users ALTER COLUMN phone_number DROP NOT NULL;
