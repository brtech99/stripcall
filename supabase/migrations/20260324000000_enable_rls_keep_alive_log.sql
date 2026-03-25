-- Enable RLS on keep_alive_log to silence the Supabase security warning.
-- The table is intentionally public read/write (used by a GitHub Action
-- that pokes the project to prevent inactivity freezes).

ALTER TABLE public.keep_alive_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow_all" ON public.keep_alive_log
  FOR ALL
  USING (true)
  WITH CHECK (true);
