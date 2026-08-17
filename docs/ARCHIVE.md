# StripCall — Project Archive Record

**Archived: 2026-08-17** by Brian Rosen (with Claude Code).

This document records the exact state of the project at archival, what was shut
down, and everything needed to resume.

---

## Infrastructure inventory at archive time

| Component | Where | State at archival | Billing |
|---|---|---|---|
| Primary database + auth + edge functions | Supabase Cloud, project ref `wpytorahphbnzgikowgz` | **Left running** | Ongoing — cancel/pause in Supabase dashboard if desired |
| Failover site (self-hosted Supabase) | Hetzner Cloud, server `ubuntu-4gb-ash-1`, Ashburn, IP `178.156.249.78`, DNS `supabase.stripcall.us` | **Powered off 2026-08-17** (see below) | ⚠️ A powered-off Hetzner server still bills. To stop billing: snapshot (optional) then **delete the server in the Hetzner Cloud console**. |
| Web app hosting | Hostinger, https://stripcall.us/app (FTP deploy) | **Left running** | Ongoing Hostinger plan |
| SMS | Twilio — Armorer +17542276679, Medical +13127577223, Natloff +16504803067 | **Left active** | Ongoing per-number fees — release numbers in Twilio console to stop (⚠️ released numbers are hard to get back) |
| Push notifications | Firebase Cloud Messaging (see `lib/firebase_options.dart`) | Left as-is | Free tier |
| Invite emails | Resend (`RESEND_API_KEY` in Supabase function secrets) | Left as-is | Free tier / low usage |
| Source code | https://github.com/brtech99/stripcall | Up to date on `main` | Free |
| AWS | — | **No AWS resources found.** The repo contains no AWS usage; the AWS profiles on the dev machine (`amplify-admin`, `nena-*`, account 496405866230) belong to a different project (NENA), not StripCall. Nothing was disabled. | n/a |

Secrets (Supabase keys, DB passwords, Twilio, FTP) live in
`scripts/config/secrets.sh` — **gitignored, exists only on the dev machine**.
A template is at `scripts/config/secrets.template.sh`. Losing `secrets.sh`
means re-collecting credentials from the Supabase/Twilio/Hostinger dashboards.

## Final backups (taken 2026-08-17)

Location on the dev machine (NOT in git — contains user data and secrets):

```
/Users/brosen/Downloads/stripcallC/hetzner-archive-2026-08-17/
├── backups/                      # full /var/backups/supabase tree from Hetzner
│   ├── daily/stripcall_2026-08-17.sql.gz   # ★ FINAL PROD DUMP, 944K, verified
│   ├── monthly/, weekly/, auth_sync/, *.log
├── secondary_final_2026-08-17.sql.gz       # final dump of the Hetzner secondary DB (49K)
├── stripcall-backup.env          # /etc/stripcall-backup.env (DB credentials)
└── opt-stripcall/                # backup/auth-sync/tournament scripts from the server
```

The ★ file is a complete `pg_dump` of production including the **`auth` schema
(users, identities, sessions) and all `public` tables** (71 tables). Verified
with `gunzip -t` and by inspecting COPY statements.

**Why the nightly backups were broken:** Supabase upgraded production Postgres
to 17.6; the Hetzner box had pg_dump 16, so every nightly dump from ~April
through 2026-08-16 failed with a version mismatch (20-byte empty files) and
weekly auth syncs produced 0-byte files after 2026-03-25. Fixed on 2026-08-17
by installing `postgresql-client-17` on the server, then a final good backup
was taken. **Lesson for resume: after any Supabase Postgres major upgrade,
upgrade pg_dump wherever backups run.**

The secondary DB dump is much smaller than prod (49K vs 944K) because auth
sync had been failing since March and dual-write only covers app writes; it is
kept only in case reconciliation questions come up.

## Code state

- `main` is pushed to GitHub and includes everything, including the final
  pre-archive commit (notification/failover/edit-dialog work — see below).
- All migrations in `supabase/migrations/` (through
  `20260601000100_cleanup_stale_pending_crewmembers.sql`) are **applied to
  production** (verified with `supabase migration list --linked` on 2026-08-17).
- Branches: `dual-write-failover` is fully merged into `main`.
  `origin/fix/secure-notification-function` contains only an empty
  placeholder commit — dead, ignorable.

### ⚠️ Committed but never deployed

The final commit contains work that was **never deployed to users** (it was
awaiting an Android on-device notification diagnosis when the project froze):

- Notification handling changes (`notification_service.dart`,
  `send-fcm-notification` edge function tweak, new `realtime_service.dart`,
  `notification_card.dart`, `snooze_page.dart`, `problem_notification.dart`)
- Edit-dialog "original report" callout (per
  `docs/superpowers/specs/2026-06-05-original-report-in-edit-dialog-design.md`)
- Medical withdrawal model (`medical_withdrawal.dart`; its migration IS
  applied to prod)
- Dual-write/failover client polish in `supabase_manager.dart`

The **deployed** web app (Hostinger) and TestFlight build predate this commit.
There is a known open bug: iOS push shows banner but no sound (see memory
notes / diagnostic script `scripts/fcm_sound_test.ts`).

### Known effect of the Hetzner shutdown on the live app

If the deployed app build includes the dual-write health check, it will now
see the secondary as down and may show an **orange (degraded) health
indicator**. This is expected and harmless while archived.

## What was done during archival (2026-08-17)

1. Installed `postgresql-client-17` on the Hetzner server (pgdg repo) to fix
   the broken backups.
2. Ran a final production backup and a final secondary-DB dump; verified both.
3. Copied all backups, scripts, and env files to
   `hetzner-archive-2026-08-17/` on the dev machine.
4. Removed the server's cron jobs (nightly backup + auth sync) and powered the
   server off via SSH.
5. Committed all outstanding work and this document; pushed `main`.

**Not done (left for Brian):** deleting the Hetzner server in the console
(stops billing), and any decision about cancelling Supabase Cloud / Hostinger /
Twilio numbers.

## How to resume

1. **Code**: clone https://github.com/brtech99/stripcall; restore
   `scripts/config/secrets.sh` from a backup of the dev machine or rebuild it
   from `secrets.template.sh` + provider dashboards.
2. **Run locally**: `./scripts/run_app.sh` (see `CLAUDE.md` and `TESTING.md`).
3. **Deploy web**: `./scripts/deploy_to_hostinger.sh`. **iOS**: bump build
   number in `pubspec.yaml`, `./scripts/deploy_ios_testflight.sh`.
4. **Edge functions**: `supabase functions deploy <name> --no-verify-jwt`.
5. **Database**: if Supabase Cloud project was kept, it's live as-is. If it
   was deleted, create a new project and restore
   `hetzner-archive-2026-08-17/backups/daily/stripcall_2026-08-17.sql.gz`
   (contains auth + public schemas), then update URLs/keys in `secrets.sh`,
   deploy scripts, and Supabase function secrets.
6. **Failover site (optional)**: if the Hetzner server was only powered off,
   boot it from the console, re-add the two cron jobs (documented in
   `opt-stripcall/` scripts and `docs/FAILOVER_RUNBOOK.md`). If it was
   deleted, rebuild per `FAILOVER_RUNBOOK.md` using the archived
   `opt-stripcall/` scripts and `stripcall-backup.env`; point
   `supabase.stripcall.us` DNS at the new IP.
7. **SMS**: Twilio webhooks point at the Supabase Cloud edge functions;
   `scripts/` contains the Twilio webhook provisioning script if numbers or
   URLs change.
8. **First code task on resume**: deploy and verify the committed-but-
   undeployed notification work (above), starting with the Android on-device
   diagnosis it was waiting on.
