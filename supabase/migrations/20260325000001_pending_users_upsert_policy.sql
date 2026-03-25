-- Allow UPDATE on pending_users so upsert works during account creation retries.
-- Also allow SELECT since upsert's ON CONFLICT needs to read the existing row.

CREATE POLICY "PendingUsersUpdatePolicy" ON public.pending_users
  FOR UPDATE USING (true) WITH CHECK (true);

CREATE POLICY "PendingUsersSelectPolicy" ON public.pending_users
  FOR SELECT USING (true);
