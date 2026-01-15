-- Step 1: Enable pg_cron extension (run this first)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Step 2: Create a simple keep-alive function
CREATE OR REPLACE FUNCTION keep_database_active()
RETURNS void AS $$
BEGIN
  -- Simple query to keep database active
  PERFORM count(*) FROM users LIMIT 1;
  
  -- Log the activity
  INSERT INTO public.keep_alive_log (timestamp) 
  VALUES (now())
  ON CONFLICT DO NOTHING;
  
  RAISE NOTICE 'Database keep-alive executed at %', now();
END;
$$ LANGUAGE plpgsql;

-- Step 3: Create log table for monitoring (optional)
CREATE TABLE IF NOT EXISTS public.keep_alive_log (
  id BIGSERIAL PRIMARY KEY,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Step 4: Schedule the cron job (every 6 hours)
SELECT cron.schedule(
  'keep-alive-job',
  '0 */6 * * *', -- Every 6 hours
  'SELECT keep_database_active();'
);
