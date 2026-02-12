-- Add notify_superusers flag to events table.
-- Controls whether superusers receive push notifications for this event.
-- Defaults to true (superusers get notified).
ALTER TABLE public.events ADD COLUMN notify_superusers boolean NOT NULL DEFAULT true;
