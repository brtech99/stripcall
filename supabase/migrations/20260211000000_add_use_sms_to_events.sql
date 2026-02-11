-- Add use_sms flag to events table.
-- Only one event at a time should have this set to true.
-- Controls which event receives incoming Twilio SMS messages.
ALTER TABLE public.events ADD COLUMN use_sms boolean NOT NULL DEFAULT false;
