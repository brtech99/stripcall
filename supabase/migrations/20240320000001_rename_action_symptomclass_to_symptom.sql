-- Rename the symptomclass column to symptom in the action table
-- This aligns the column name with the actual relationship (actions should be linked to symptoms, not symptom classes)

-- First, drop the existing foreign key constraint
ALTER TABLE action DROP CONSTRAINT action_symptomclass_fkey;

-- Rename the column
ALTER TABLE action RENAME COLUMN symptomclass TO symptom;

-- Add the new foreign key constraint referencing the symptom table
ALTER TABLE action ADD CONSTRAINT action_symptom_fkey 
    FOREIGN KEY (symptom) REFERENCES symptom(id);

-- Add a comment to document the change
COMMENT ON COLUMN action.symptom IS 'Foreign key reference to the symptom table. Actions are specific resolutions for particular symptoms.'; 