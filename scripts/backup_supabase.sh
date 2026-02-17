#!/bin/bash
# backup_supabase.sh — Daily pg_dump of Supabase production database
#
# Rotation policy:
#   Daily:   kept for 7 days
#   Weekly:  Wednesday dump kept for 5 weeks (approximately one month)
#   Monthly: 1st-of-month dump kept for 12 months, except August
#   August:  monthly dump kept forever (yearly archive)
#
# Intended to run via cron at 4:00 AM Eastern daily on the Hetzner server.
# All times/dates use the system clock (set to America/New_York).

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────

BACKUP_DIR="/var/backups/supabase"
DAILY_DIR="$BACKUP_DIR/daily"
WEEKLY_DIR="$BACKUP_DIR/weekly"
MONTHLY_DIR="$BACKUP_DIR/monthly"
ARCHIVE_DIR="$BACKUP_DIR/archive"
LOG_FILE="$BACKUP_DIR/backup.log"

# Database connection — set these as environment variables or edit here.
# When run from cron, these are set in /etc/stripcall-backup.env
DB_HOST="${SUPABASE_DB_HOST:?SUPABASE_DB_HOST not set}"
DB_PORT="${SUPABASE_DB_PORT:-5432}"
DB_NAME="${SUPABASE_DB_NAME:-postgres}"
DB_USER="${SUPABASE_DB_USER:-postgres}"
DB_PASS="${SUPABASE_DB_PASS:?SUPABASE_DB_PASS not set}"

# ── Helpers ────────────────────────────────────────────────────────────────────

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

die() {
  log "ERROR: $1"
  exit 1
}

# ── Setup directories ─────────────────────────────────────────────────────────

mkdir -p "$DAILY_DIR" "$WEEKLY_DIR" "$MONTHLY_DIR" "$ARCHIVE_DIR"

# ── Dump ───────────────────────────────────────────────────────────────────────

DATE=$(date '+%Y-%m-%d')
DAY_OF_WEEK=$(date '+%u')   # 1=Monday … 7=Sunday
DAY_OF_MONTH=$(date '+%d')  # 01-31
MONTH=$(date '+%m')          # 01-12

DUMP_FILE="$DAILY_DIR/stripcall_${DATE}.sql.gz"

log "Starting backup for $DATE"

export PGPASSWORD="$DB_PASS"

pg_dump \
  --host="$DB_HOST" \
  --port="$DB_PORT" \
  --username="$DB_USER" \
  --dbname="$DB_NAME" \
  --no-owner \
  --no-privileges \
  --format=plain \
  --verbose \
  2>>"$LOG_FILE" \
  | gzip > "$DUMP_FILE" \
  || die "pg_dump failed"

unset PGPASSWORD

DUMP_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
log "Daily dump complete: $DUMP_FILE ($DUMP_SIZE)"

# ── Weekly copy (Wednesday = day 3) ───────────────────────────────────────────

if [ "$DAY_OF_WEEK" -eq 3 ]; then
  cp "$DUMP_FILE" "$WEEKLY_DIR/stripcall_weekly_${DATE}.sql.gz"
  log "Weekly copy saved"
fi

# ── Monthly copy (1st of month) ───────────────────────────────────────────────

if [ "$DAY_OF_MONTH" = "01" ]; then
  if [ "$MONTH" = "08" ]; then
    # August monthly → archive (kept forever)
    cp "$DUMP_FILE" "$ARCHIVE_DIR/stripcall_august_${DATE}.sql.gz"
    log "August archive saved (permanent)"
  fi
  # All months get a monthly copy (including August, for the 12-month window)
  cp "$DUMP_FILE" "$MONTHLY_DIR/stripcall_monthly_${DATE}.sql.gz"
  log "Monthly copy saved"
fi

# ── Cleanup: daily older than 7 days ──────────────────────────────────────────

find "$DAILY_DIR" -name "*.sql.gz" -mtime +7 -delete
DELETED=$(find "$DAILY_DIR" -name "*.sql.gz" -mtime +7 2>/dev/null | wc -l)
log "Daily cleanup: removed files older than 7 days"

# ── Cleanup: weekly older than 35 days (~5 weeks) ────────────────────────────

find "$WEEKLY_DIR" -name "*.sql.gz" -mtime +35 -delete
log "Weekly cleanup: removed files older than 35 days"

# ── Cleanup: monthly older than 365 days ─────────────────────────────────────

find "$MONTHLY_DIR" -name "*.sql.gz" -mtime +365 -delete
log "Monthly cleanup: removed files older than 365 days"

# ── Archive is never cleaned up ──────────────────────────────────────────────

log "Backup complete. Daily: $(ls "$DAILY_DIR"/*.sql.gz 2>/dev/null | wc -l), Weekly: $(ls "$WEEKLY_DIR"/*.sql.gz 2>/dev/null | wc -l), Monthly: $(ls "$MONTHLY_DIR"/*.sql.gz 2>/dev/null | wc -l), Archive: $(ls "$ARCHIVE_DIR"/*.sql.gz 2>/dev/null | wc -l)"
log "---"
