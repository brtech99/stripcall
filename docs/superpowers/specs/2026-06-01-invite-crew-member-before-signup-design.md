# Invite a crew member before they finish signing up

**Date:** 2026-06-01
**Status:** Approved (design)

## Problem

During field testing and early deployment, a crew chief wants to add a person to a
crew *before* that person has finished creating their account. Today this is impossible:

- `crewmembers.crewmember` is a foreign key to `users.supabase_id`.
- A `users` row only exists *after* the person confirms their email during signup
  (created by `ensureUserRecord()` in `router.dart`).
- The chief's "add member" UI (`manage_crew_page.dart` → `NameFinderDialog` →
  `search_users()` RPC) searches **only** the `users` table, so a not-yet-registered
  person can't be found or added.

There is a `pending_users` table, but it only holds in-flight signup data (keyed by
email) and is not wired to crews.

This is a startup-phase need that will fade as the user base stabilizes, so the design
favors a lightweight, well-isolated mechanism that is easy to retire later.

## Requirements (from brainstorming)

- The chief adds a not-yet-registered person **by email**.
- Adding **sends that person an email invitation** to create their account, with the
  email (and name) pre-filled into the signup form.
- The invitee appears in the crew roster as **"Invited / pending"** during the gap.
- When the invitee completes signup **with that email**, they **automatically become a
  normal crew member** and the pending entry is cleared.

## Approach (chosen)

**Pending invite records + auto-reconcile.** A small `pending_crewmembers` table holds
crew assignments keyed by email. The roster shows real members plus pending invites. A
database trigger reconciles pending invites into real `crewmembers` rows when the
`users` row is created at signup. `crewmembers` keeps its clean FK to `users`; the
invitee goes through the existing real signup flow; nothing is created prematurely; the
whole mechanism is one table + one trigger + one edge function and is trivial to remove
later.

(Rejected: creating a stub auth account at invite time — it creates credentials the
person never requested, collides with the custom signup+OTP flow, and is messier to
unwind.)

## Design

### 1. Data model — `pending_crewmembers`

```sql
CREATE TABLE public.pending_crewmembers (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  crew        bigint NOT NULL REFERENCES public.crews(id) ON DELETE CASCADE,
  email       text   NOT NULL,              -- stored lowercased + trimmed (match key)
  firstname   text,                         -- for roster display + signup prefill
  lastname    text,
  invited_by  text REFERENCES public.users(supabase_id),
  invited_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.pending_crewmembers ENABLE ROW LEVEL SECURITY;

-- Expression uniqueness requires a unique index (not a table constraint):
CREATE UNIQUE INDEX pending_crewmembers_crew_email_uidx
  ON public.pending_crewmembers (crew, lower(email));
```

RLS (mirrors existing crew patterns):
- **Insert / delete:** the crew's `crew_chief` or a superuser.
- **Select:** crew members of that crew, the crew chief, or a superuser (so it can be
  shown in the roster).

`firstname`/`lastname` are collected at invite time so the pending roster entry shows a
real name and the signup form can pre-fill it.

### 2. Invite flow — `invite-crew-member` edge function

`verify_jwt = true` (called by the authenticated chief). Input: `{ crew_id, email,
firstname, lastname }`.

1. **Authorize:** caller must be the crew's `crew_chief` (or a superuser).
2. **Normalize** email (lowercase, trim).
3. **Already registered?** `public.users` has no email column — email lives in
   `auth.users`. Query `auth.users` by email. If a matching auth user exists (and has a
   `public.users` row), insert directly into `crewmembers` (ON CONFLICT DO NOTHING) and
   return `"added"`. Skip the pending/invite path.
4. **Otherwise** upsert into `pending_crewmembers` on `(crew, lower(email))`
   (re-invite updates `invited_at`).
5. **Send invite email** reusing the existing Resend path used by `send-signup-otp`. The
   email contains a deep link:
   `https://stripcall.us/app/#/create-account?email=<email>&firstname=<fn>&lastname=<ln>`
6. Return `"invited"`.

### 3. Signup prefill — `create_account_page.dart`

Read `email`, `firstname`, `lastname` from the route query parameters. Pre-fill the
corresponding fields and **lock the email field** (read-only) so the invitee signs up
with the address that was invited, guaranteeing the reconciliation match.

### 4. Reconciliation — DB trigger on signup

A `SECURITY DEFINER` trigger function `AFTER INSERT ON public.users`:

```text
email := (SELECT email FROM auth.users WHERE id = NEW.supabase_id);
FOR pc IN SELECT * FROM pending_crewmembers WHERE lower(email) = lower(<email>) LOOP
    INSERT INTO crewmembers (crew, crewmember)
      VALUES (pc.crew, NEW.supabase_id)
      ON CONFLICT DO NOTHING;
    DELETE FROM pending_crewmembers WHERE id = pc.id;
END LOOP;
```

A trigger (rather than app code in `ensureUserRecord`) fires regardless of how the
`users` row is created and works independently on the primary and failover databases.
The migration that creates the trigger must be applied to both databases, consistent
with the existing dual-write architecture.

### 5. Roster UI — `manage_crew_page.dart`

- Load real members (existing path) **plus** `pending_crewmembers` for the crew.
- Render pending entries with an **"Invited"** badge showing name + email.
- Pending-entry actions: **Resend** (re-call the edge function) and **Cancel** (delete
  the `pending_crewmembers` row).
- In the add-member dialog, when a name search returns nothing, offer **"Invite by
  email"** → a small form (email, first name, last name) → calls `invite-crew-member`.

### 6. Edge cases & cleanup

- **Different email at signup:** invite stays pending; the chief cancels it and adds the
  person normally once they appear in `search_users`.
- **Crew deleted:** pending rows cascade away (`ON DELETE CASCADE`).
- **Duplicate invite:** upsert on `(crew, lower(email))`.
- **Stale invites:** extend the existing stale-cleanup cron (alongside
  `cleanup_stale_pending_users`) to prune `pending_crewmembers` older than ~6 months.

### Security trade-off (accepted)

The invite link's email is a **pre-fill, not a secret token**. Anyone who signs up with
a given email is auto-added to whatever crews invited that email. In a tournament-staff
context this is low-risk and acceptable. A real per-invite token can be added later if
needed.

## Out of scope (YAGNI)

- Per-invite tokens / expiry.
- An approval/confirm step before linking (auto-link was chosen).
- Bulk/multi-crew invites.

## Components touched

- **New migration:** `pending_crewmembers` table + RLS + reconciliation trigger
  (+ stale cleanup).
- **New edge function:** `invite-crew-member`.
- **Flutter:** `create_account_page.dart` (prefill/lock email), `manage_crew_page.dart`
  (pending invites in roster + invite-by-email + resend/cancel), and the data layer they
  use.
- **Cleanup cron:** extend existing stale-cleanup to cover `pending_crewmembers`.

## Retirement (when the startup phase ends)

Stop offering "Invite by email" in the UI and drop the `pending_crewmembers` table and
its trigger. Nothing else in the identity/crew model depends on it.
