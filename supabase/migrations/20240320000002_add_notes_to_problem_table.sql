-- Add notes column to the problem table
-- This allows users to add notes when resolving problems

ALTER TABLE problem ADD COLUMN notes TEXT;

-- Add a comment to document the new column
COMMENT ON COLUMN problem.notes IS 'Optional notes added when resolving a problem'; 