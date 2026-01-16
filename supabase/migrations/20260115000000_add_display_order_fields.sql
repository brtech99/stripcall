-- Add display_order fields to symptomclass, symptom, and action tables

-- Add display_order to symptomclass
ALTER TABLE public.symptomclass
ADD COLUMN IF NOT EXISTS display_order integer DEFAULT 0;

-- Add display_order to symptom
ALTER TABLE public.symptom
ADD COLUMN IF NOT EXISTS display_order integer DEFAULT 0;

-- Add display_order to action
ALTER TABLE public.action
ADD COLUMN IF NOT EXISTS display_order integer DEFAULT 0;

-- Initialize display_order values based on current alphabetical order
-- This ensures existing data has sequential order values

-- Update symptomclass display_order
WITH ordered_classes AS (
  SELECT id, ROW_NUMBER() OVER (PARTITION BY "crewType" ORDER BY symptomclassstring) - 1 as new_order
  FROM public.symptomclass
)
UPDATE public.symptomclass sc
SET display_order = oc.new_order
FROM ordered_classes oc
WHERE sc.id = oc.id;

-- Update symptom display_order
WITH ordered_symptoms AS (
  SELECT id, ROW_NUMBER() OVER (PARTITION BY symptomclass ORDER BY symptomstring) - 1 as new_order
  FROM public.symptom
)
UPDATE public.symptom s
SET display_order = os.new_order
FROM ordered_symptoms os
WHERE s.id = os.id;

-- Update action display_order (note: action table references symptomclass, not symptom based on migration 20240320000001)
WITH ordered_actions AS (
  SELECT id, ROW_NUMBER() OVER (PARTITION BY symptom ORDER BY actionstring) - 1 as new_order
  FROM public.action
)
UPDATE public.action a
SET display_order = oa.new_order
FROM ordered_actions oa
WHERE a.id = oa.id;
