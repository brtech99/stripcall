-- Create crew_messages table for general crew communication
-- This allows crews to send messages to each other not related to specific problems

CREATE TABLE IF NOT EXISTS crew_messages (
    id SERIAL PRIMARY KEY,
    crew INTEGER NOT NULL REFERENCES crews(id) ON DELETE CASCADE,
    author TEXT NOT NULL REFERENCES users(supabase_id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_crew_messages_crew ON crew_messages(crew);
CREATE INDEX IF NOT EXISTS idx_crew_messages_created_at ON crew_messages(created_at);
CREATE INDEX IF NOT EXISTS idx_crew_messages_author ON crew_messages(author);

-- Add RLS (Row Level Security) policies
ALTER TABLE crew_messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see messages from crews they belong to
DROP POLICY IF EXISTS "Users can view crew messages for their crews" ON crew_messages;
CREATE POLICY "Users can view crew messages for their crews" ON crew_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM crewmembers 
            WHERE crewmembers.crew = crew_messages.crew 
            AND crewmembers.crewmember = auth.uid()::text
        )
    );

-- Policy: Users can only insert messages for crews they belong to
DROP POLICY IF EXISTS "Users can insert crew messages for their crews" ON crew_messages;
CREATE POLICY "Users can insert crew messages for their crews" ON crew_messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM crewmembers 
            WHERE crewmembers.crew = crew_messages.crew 
            AND crewmembers.crewmember = auth.uid()::text
        )
    );

-- Policy: Users can only update their own messages
DROP POLICY IF EXISTS "Users can update their own crew messages" ON crew_messages;
CREATE POLICY "Users can update their own crew messages" ON crew_messages
    FOR UPDATE USING (author = auth.uid()::text);

-- Policy: Users can only delete their own messages
DROP POLICY IF EXISTS "Users can delete their own crew messages" ON crew_messages;
CREATE POLICY "Users can delete their own crew messages" ON crew_messages
    FOR DELETE USING (author = auth.uid()::text);

-- Add comments to document the table
COMMENT ON TABLE crew_messages IS 'General crew communication messages not tied to specific problems';
COMMENT ON COLUMN crew_messages.crew IS 'Foreign key reference to the crew this message belongs to';
COMMENT ON COLUMN crew_messages.author IS 'Foreign key reference to the user who sent the message';
COMMENT ON COLUMN crew_messages.message IS 'The message content';
COMMENT ON COLUMN crew_messages.created_at IS 'Timestamp when the message was created';
COMMENT ON COLUMN crew_messages.updated_at IS 'Timestamp when the message was last updated'; 