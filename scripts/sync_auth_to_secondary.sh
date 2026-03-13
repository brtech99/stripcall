#!/bin/bash
# sync_auth_to_secondary.sh — Replicate auth.users from primary Supabase to secondary
#
# This syncs the primary's auth schema (users, identities, sessions, etc.)
# to the self-hosted secondary instance so it can serve as a real failover.
#
# Strategy:
#   1. pg_dump auth tables from primary (hosted Supabase)
#   2. Wipe auth tables on secondary (self-hosted)
#   3. pg_restore into secondary
#
# This preserves password hashes so users can log in to the secondary
# without re-authenticating.
#
# Schedule:
#   - Weekly (Wednesday) during normal operation
#   - Daily during tournament weeks
#   - Always at 4:00 AM Eastern (no tournament is running at that hour)
#
# Intended to run via cron on the Hetzner server alongside backup_supabase.sh.
# Credentials come from /etc/stripcall-backup.env (extended by setup script).

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────

LOG_DIR="/var/backups/supabase"
LOG_FILE="$LOG_DIR/auth_sync.log"
DUMP_DIR="/var/backups/supabase/auth_sync"
TOURNAMENT_FLAG="/opt/stripcall/tournament_active"

# Primary DB (hosted Supabase)
PRIMARY_DB_HOST="${SUPABASE_DB_HOST:?SUPABASE_DB_HOST not set}"
PRIMARY_DB_PORT="${SUPABASE_DB_PORT:-5432}"
PRIMARY_DB_NAME="${SUPABASE_DB_NAME:-postgres}"
PRIMARY_DB_USER="${SUPABASE_DB_USER:-postgres}"
PRIMARY_DB_PASS="${SUPABASE_DB_PASS:?SUPABASE_DB_PASS not set}"

# Secondary DB (self-hosted Supabase on this server)
SECONDARY_DB_HOST="${SUPABASE_SECONDARY_DB_HOST:-localhost}"
SECONDARY_DB_PORT="${SUPABASE_SECONDARY_DB_PORT:-5432}"
SECONDARY_DB_NAME="${SUPABASE_SECONDARY_DB_NAME:-postgres}"
SECONDARY_DB_USER="${SUPABASE_SECONDARY_DB_USER:-postgres}"
SECONDARY_DB_PASS="${SUPABASE_SECONDARY_DB_PASS:?SUPABASE_SECONDARY_DB_PASS not set}"

# ── Helpers ────────────────────────────────────────────────────────────────────

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [auth-sync] $1" | tee -a "$LOG_FILE"
}

die() {
  log "ERROR: $1"
  exit 1
}

# ── Should we run today? ──────────────────────────────────────────────────────
# Weekly on Wednesday (day 3) unless tournament is active → then daily.

DAY_OF_WEEK=$(date '+%u')  # 1=Monday … 7=Sunday

if [ -f "$TOURNAMENT_FLAG" ]; then
  log "Tournament mode active — running daily sync"
else
  if [ "$DAY_OF_WEEK" -ne 3 ]; then
    log "Not Wednesday and no tournament — skipping auth sync"
    exit 0
  fi
  log "Weekly Wednesday sync"
fi

# ── Setup ─────────────────────────────────────────────────────────────────────

mkdir -p "$DUMP_DIR"

DATE=$(date '+%Y-%m-%d_%H%M%S')
DUMP_FILE="$DUMP_DIR/auth_dump_${DATE}.sql"

# ── Tables to sync ────────────────────────────────────────────────────────────
# Core auth tables that contain user credentials and session data.
# We sync these so users can authenticate against the secondary.

AUTH_TABLES=(
  "auth.users"
  "auth.identities"
  "auth.mfa_factors"
  "auth.mfa_challenges"
  "auth.mfa_amr_claims"
  "auth.refresh_tokens"
  "auth.sessions"
)

# ── Step 1: Dump auth tables from primary ─────────────────────────────────────

log "Dumping auth tables from primary ($PRIMARY_DB_HOST)..."

export PGPASSWORD="$PRIMARY_DB_PASS"

# Build the --table flags
TABLE_FLAGS=""
for tbl in "${AUTH_TABLES[@]}"; do
  TABLE_FLAGS="$TABLE_FLAGS --table=$tbl"
done

pg_dump \
  --host="$PRIMARY_DB_HOST" \
  --port="$PRIMARY_DB_PORT" \
  --username="$PRIMARY_DB_USER" \
  --dbname="$PRIMARY_DB_NAME" \
  --no-owner \
  --no-privileges \
  --data-only \
  --disable-triggers \
  --format=plain \
  $TABLE_FLAGS \
  > "$DUMP_FILE" \
  2>>"$LOG_FILE" \
  || die "pg_dump of auth tables failed"

unset PGPASSWORD

DUMP_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
log "Auth dump complete: $DUMP_FILE ($DUMP_SIZE)"

# Sanity check: dump should contain data
if [ ! -s "$DUMP_FILE" ]; then
  die "Auth dump file is empty — aborting restore"
fi

USER_COUNT=$(grep -c "^COPY auth.users" "$DUMP_FILE" 2>/dev/null || echo "0")
log "Dump contains COPY statements for auth.users: $USER_COUNT"

# ── Step 2: Restore to secondary ─────────────────────────────────────────────

log "Restoring auth tables to secondary ($SECONDARY_DB_HOST:$SECONDARY_DB_PORT)..."

export PGPASSWORD="$SECONDARY_DB_PASS"

# Truncate existing auth data on secondary before restore.
# Order matters due to foreign keys — truncate with CASCADE.
psql \
  --host="$SECONDARY_DB_HOST" \
  --port="$SECONDARY_DB_PORT" \
  --username="$SECONDARY_DB_USER" \
  --dbname="$SECONDARY_DB_NAME" \
  --set ON_ERROR_STOP=off \
  -c "
    -- Disable triggers during truncate/restore
    SET session_replication_role = replica;

    TRUNCATE auth.sessions CASCADE;
    TRUNCATE auth.refresh_tokens CASCADE;
    TRUNCATE auth.mfa_amr_claims CASCADE;
    TRUNCATE auth.mfa_challenges CASCADE;
    TRUNCATE auth.mfa_factors CASCADE;
    TRUNCATE auth.identities CASCADE;
    TRUNCATE auth.users CASCADE;
  " \
  2>>"$LOG_FILE" \
  || die "Failed to truncate auth tables on secondary"

log "Secondary auth tables truncated"

# Restore the dump
psql \
  --host="$SECONDARY_DB_HOST" \
  --port="$SECONDARY_DB_PORT" \
  --username="$SECONDARY_DB_USER" \
  --dbname="$SECONDARY_DB_NAME" \
  --set ON_ERROR_STOP=off \
  -c "SET session_replication_role = replica;" \
  -f "$DUMP_FILE" \
  2>>"$LOG_FILE" \
  || die "Failed to restore auth tables to secondary"

# Re-enable triggers
psql \
  --host="$SECONDARY_DB_HOST" \
  --port="$SECONDARY_DB_PORT" \
  --username="$SECONDARY_DB_USER" \
  --dbname="$SECONDARY_DB_NAME" \
  -c "SET session_replication_role = DEFAULT;" \
  2>>"$LOG_FILE"

unset PGPASSWORD

log "Auth tables restored to secondary"

# ── Step 3: Verify ────────────────────────────────────────────────────────────

export PGPASSWORD="$SECONDARY_DB_PASS"

SECONDARY_USER_COUNT=$(psql \
  --host="$SECONDARY_DB_HOST" \
  --port="$SECONDARY_DB_PORT" \
  --username="$SECONDARY_DB_USER" \
  --dbname="$SECONDARY_DB_NAME" \
  --tuples-only \
  -c "SELECT count(*) FROM auth.users;" \
  2>>"$LOG_FILE" | tr -d ' ')

unset PGPASSWORD

log "Secondary now has $SECONDARY_USER_COUNT auth users"

# ── Cleanup old dumps (keep last 7) ──────────────────────────────────────────

ls -t "$DUMP_DIR"/auth_dump_*.sql 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null
log "Auth sync complete"
log "---"
