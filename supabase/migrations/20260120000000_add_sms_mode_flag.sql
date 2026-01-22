-- Add SMS mode flag to users table
-- When true, the user receives messages via SMS instead of app notifications

ALTER TABLE users ADD COLUMN IF NOT EXISTS is_sms_mode BOOLEAN DEFAULT FALSE;

-- Index for quick lookup of SMS mode users
CREATE INDEX IF NOT EXISTS idx_users_sms_mode ON users(is_sms_mode) WHERE is_sms_mode = TRUE;
