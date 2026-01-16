-- Add include_reporter field to messages table
ALTER TABLE messages ADD COLUMN IF NOT EXISTS include_reporter BOOLEAN DEFAULT true;

-- Add comment
COMMENT ON COLUMN messages.include_reporter IS 'Whether the problem reporter should see this message';

-- Create index for faster filtering
CREATE INDEX IF NOT EXISTS idx_messages_include_reporter ON messages(problem, include_reporter);
