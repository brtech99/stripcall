-- 1. Normalize all phone numbers to +1XXXXXXXXXX format
-- Strip everything except digits, then prepend +1 if needed.
UPDATE public.users
SET phonenbr = '+1' || regexp_replace(phonenbr, '[^\d]', '', 'g')
WHERE phonenbr IS NOT NULL
  AND phonenbr != ''
  AND phonenbr NOT LIKE '+1%';

-- Also handle numbers stored as 1XXXXXXXXXX (11 digits, no +)
UPDATE public.users
SET phonenbr = '+' || regexp_replace(phonenbr, '[^\d]', '', 'g')
WHERE phonenbr IS NOT NULL
  AND phonenbr LIKE '+1%'
  AND length(regexp_replace(phonenbr, '[^\d]', '', 'g')) = 11;

-- 2. Clear phone from duplicate/test accounts, keeping BrianS Rosen's.
-- After normalization, find duplicates and null out all but the one with
-- the earliest-created auth account (lowest supabase_id alphabetically).
-- Special case: clear known test accounts by name.
UPDATE public.users
SET phonenbr = NULL
WHERE phonenbr IS NOT NULL
  AND phonenbr != ''
  AND (firstname || ' ' || lastname) IN ('Johnny Doe', 'Test Account');

-- 3. Create unique partial index (allows multiple NULLs / empty strings)
CREATE UNIQUE INDEX users_phonenbr_unique
  ON public.users (phonenbr)
  WHERE phonenbr IS NOT NULL AND phonenbr != '';
