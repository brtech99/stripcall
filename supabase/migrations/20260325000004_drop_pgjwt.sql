-- Drop pgjwt extension — required for Postgres version upgrade.
-- We don't use this extension anywhere in our code.
DROP EXTENSION IF EXISTS pgjwt;
