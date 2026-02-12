# RLS Policy Review

## Executive Summary

This document provides a detailed review of the Row-Level Security (RLS) policies for the StripCall application. The policies were captured from the live Supabase environment and added to the migration `..._remote_schema.sql`.

Overall, the RLS policies are well-structured and provide a solid security foundation. They correctly use helper functions like `is_superuser` and `is_crew_chief` to centralize permission logic. Most policies accurately reflect the business rules outlined in the `StripCallAppRules.md` document.

However, this review identifies a few key areas where the policies are either too restrictive, potentially not matching the intended application behavior, or could be improved to better handle administrative tasks.

The following sections provide a table-by-table analysis and a prioritized list of recommendations.

---

## High-Priority Recommendations

### 1. Align `crews` Write Policies with Event Organizer Role
- **Tables:** `crews`
- **Policies:** `crews_delete_policy`, `crews_update_policy`
- **Issue:** Currently, an organizer can only update or delete a crew if they are also the `crew_chief` for that specific crew. The business rules state that an organizer should be able to manage all crews for an event they own.
- **Recommendation:** Modify the `delete` and `update` policies for the `crews` table to check if the user is the organizer of the parent event, rather than the crew chief of the crew itself.

**Proposed `crews_update_policy` and `crews_delete_policy`:**
```sql
-- For DELETE
USING (
  is_superuser(auth.uid()) OR 
  EXISTS (
    SELECT 1 FROM events e 
    WHERE e.id = crews.event AND e.organizer = auth.uid()::text
  )
)

-- For UPDATE
USING (
  is_superuser(auth.uid()) OR 
  EXISTS (
    SELECT 1 FROM events e 
    WHERE e.id = crews.event AND e.organizer = auth.uid()::text
  )
)
```

---

## Medium-Priority Recommendations

### 1. Allow Admins to Manage `pending_users`
- **Table:** `pending_users`
- **Policies:** `PendingUsersReadPolicy`, `PendingUsersDeletePolicy`
- **Issue:** Currently, only an authenticated user can read or delete from `pending_users`. This leaves no way for a superuser to clean up stale pending user records (e.g., users who never confirmed their email).
- **Recommendation:** Modify the `read` and `delete` policies to also allow access for superusers.

**Proposed `PendingUsersReadPolicy` and `PendingUsersDeletePolicy`:**
```sql
USING (
  is_superuser(auth.uid()) OR
  auth.role() = 'authenticated'::text
)
```

### 2. Allow Crew Chiefs to Create `oldproblemsymptom` Records
- **Table:** `oldproblemsymptom`
- **Policy:** `oldproblemsymptom_write_policy`
- **Issue:** Only superusers can write to this table. However, the application logic implies that a crew chief should be able to change a problem's symptom, which would require creating a record in this table to log the change. The current policy would block this action.
- **Recommendation:** Loosen the `write` policy to allow crew chiefs to insert into this table. A full `ALL` policy might be too permissive; an `INSERT` policy is likely sufficient.

**Proposed `oldproblemsymptom_insert_policy`:**
```sql
-- (Replacing the old 'write' policy)
CREATE POLICY "oldproblemsymptom_insert_policy"
ON "public"."oldproblemsymptom"
AS PERMISSIVE FOR INSERT
TO public
WITH CHECK (
  is_superuser(auth.uid()) OR
  EXISTS (
    SELECT 1 FROM problem p
    WHERE p.id = oldproblemsymptom.problem AND is_crew_chief(auth.uid(), p.crew)
  )
);
```

---

## Low-Priority Recommendations & Discussion Points

### 1. Missing `update`/`delete` Policies for `messages`
- **Table:** `messages`
- **Issue:** There are no policies for updating or deleting messages.
- **Analysis:** This is likely intentional to maintain a clear and unalterable communication log for each problem. This is a sound security practice. However, it's worth confirming if this is the desired behavior. If an admin or user needs to be able to redact or delete a message, new policies would be required.
- **Recommendation:** No change is needed unless the business requirements state otherwise. This is more of a confirmation point.

### 2. Missing `update`/`delete` Policies for `responders`
- **Table:** `responders`
- **Issue:** There are no policies for updating or deleting records. This means a user cannot "un-respond" or remove themselves from a problem once they have indicated they are on their way.
- **Analysis:** Similar to the `messages` table, this may be intentional. However, it's more likely that a user should be able to cancel their response.
- **Recommendation:** Consider adding a `delete` policy that allows a user to delete their own responder record.

**Proposed `responders_delete_policy`:**
```sql
CREATE POLICY "responders_delete_policy"
ON "public"."responders"
AS PERMISSIVE FOR DELETE
TO public
USING (
  is_superuser(auth.uid()) OR
  user_id = auth.uid()::text
);
```

---

## Full Policy Analysis (By Table)

### `users`
- **Policies:** `create`, `delete`, `read`, `update`
- **Analysis:** **Excellent.** The policies are secure and correctly implement the logic that users can manage their own data and superusers can manage all data. No changes recommended.

### `events`
- **Policies:** `create`, `delete`, `read`, `update`
- **Analysis:** **Excellent.** Any authenticated user can read events. Write access is correctly limited to superusers and the event's designated organizer. No changes recommended.

### `crews`
- **Policies:** `create`, `delete`, `read`, `update`
- **Analysis:** **Needs Improvement.** The `read` and `create` policies are good. However, the `update` and `delete` policies are too restrictive, as they require an organizer to also be the crew chief. See **High-Priority Recommendation #1**.

### `crewmembers`
- **Policies:** `create`, `delete`, `read`, `update`
- **Analysis:** **Good.** Policies correctly allow superusers and crew chiefs to manage the members of a crew. Users can see their own membership. No changes recommended.

### `problem`
- **Policies:** `create`, `delete`, `read`, `update`
- **Analysis:** **Excellent.** These policies are well-thought-out. They correctly allow crew members to see and create problems for their crew, while giving crew chiefs and the original reporter appropriate update and delete permissions. No changes recommended.

### `messages`
- **Policies:** `create`, `read`
- **Analysis:** **Good (with a question).** The `create` and `read` policies are correct. The lack of `update` and `delete` is likely intentional but should be confirmed. See **Low-Priority Recommendation #1**.

### `action`, `symptom`, `symptomclass`
- **Policies:** `read`, `write`
- **Analysis:** **Good.** These lookup tables are correctly configured to be readable by any authenticated user but only writable by superusers. This is a secure and standard pattern.

### `oldproblemsymptom`
- **Policies:** `read`, `write`
- **Analysis:** **Needs Improvement.** The `read` policy is correct, but the `write` policy is too restrictive and would likely cause bugs in the application. See **Medium-Priority Recommendation #2**.

### `responders`
- **Policies:** `create`, `read`
- **Analysis:** **Good (with a question).** The `create` and `read` policies are correct. The lack of a `delete` policy means users cannot "un-respond". See **Low-Priority Recommendation #2**.

### `notification_preferences`, `device_tokens`
- **Policies:** `all`
- **Analysis:** **Excellent.** These tables correctly implement the policy that a user can only manage their own records. This is secure and correct.

### `pending_users`
- **Policies:** `delete`, `insert`, `read`
- **Analysis:** **Needs Improvement.** The `insert` policy is correctly public. The `read` and `delete` policies should be expanded to allow superusers to perform cleanup. See **Medium-Priority Recommendation #2**.

