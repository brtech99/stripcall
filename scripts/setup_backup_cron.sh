#!/bin/bash
# setup_backup_cron.sh — Install the Supabase backup cron job on the Hetzner server.
#
# Usage:
#   1. Fill in SUPABASE_DB_PASS in scripts/config/secrets.sh
#   2. From your local machine, run:
#        ./scripts/setup_backup_cron.sh
#
#   This will:
#     - Copy the backup script to the Hetzner server
#     - Create the credentials env file on the server
#     - Set the server timezone to America/New_York
#     - Install the cron job (4:00 AM Eastern daily)
#     - Ensure pg_dump (postgresql-client) is installed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SECRETS_FILE="$SCRIPT_DIR/config/secrets.sh"

# Load secrets
if [ ! -f "$SECRETS_FILE" ]; then
  echo "ERROR: $SECRETS_FILE not found. Copy from secrets.template.sh and fill in values."
  exit 1
fi
source "$SECRETS_FILE"

# Validate required variables
for var in SUPABASE_DB_HOST SUPABASE_DB_PORT SUPABASE_DB_NAME SUPABASE_DB_USER SUPABASE_DB_PASS; do
  if [ -z "${!var:-}" ] || [ "${!var}" = "YOUR-PASSWORD-HERE" ]; then
    echo "ERROR: $var is not set or still has placeholder value in secrets.sh"
    exit 1
  fi
done

HETZNER_HOST="supabase.stripcall.us"
REMOTE_SCRIPT="/opt/stripcall/backup_supabase.sh"
REMOTE_ENV="/etc/stripcall-backup.env"

echo "=== Setting up Supabase backup on $HETZNER_HOST ==="

# 1. Copy backup script to server
echo "--- Copying backup script ---"
ssh "root@$HETZNER_HOST" "mkdir -p /opt/stripcall /var/backups/supabase"
scp "$SCRIPT_DIR/backup_supabase.sh" "root@$HETZNER_HOST:$REMOTE_SCRIPT"
ssh "root@$HETZNER_HOST" "chmod +x $REMOTE_SCRIPT"

# 2. Create credentials env file on server (not world-readable)
echo "--- Writing credentials ---"
ssh "root@$HETZNER_HOST" "cat > $REMOTE_ENV << 'ENVEOF'
export SUPABASE_DB_HOST=$SUPABASE_DB_HOST
export SUPABASE_DB_PORT=$SUPABASE_DB_PORT
export SUPABASE_DB_NAME=$SUPABASE_DB_NAME
export SUPABASE_DB_USER=$SUPABASE_DB_USER
export SUPABASE_DB_PASS=$SUPABASE_DB_PASS
ENVEOF
chmod 600 $REMOTE_ENV"

# 3. Set timezone to Eastern
echo "--- Setting timezone to America/New_York ---"
ssh "root@$HETZNER_HOST" "timedatectl set-timezone America/New_York 2>/dev/null || ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime"

# 4. Ensure postgresql-client is installed (for pg_dump)
echo "--- Ensuring postgresql-client is installed ---"
ssh "root@$HETZNER_HOST" "which pg_dump >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq postgresql-client)"

# 5. Install cron job
# Source the env file, then run the backup script. Logs go to backup.log via the script itself.
CRON_LINE="0 4 * * * . $REMOTE_ENV && $REMOTE_SCRIPT >> /var/backups/supabase/cron.log 2>&1"

echo "--- Installing cron job ---"
ssh "root@$HETZNER_HOST" "(crontab -l 2>/dev/null | grep -v 'backup_supabase.sh'; echo '$CRON_LINE') | crontab -"

# 6. Verify
echo ""
echo "=== Setup complete ==="
echo ""
ssh "root@$HETZNER_HOST" "echo 'Cron entry:' && crontab -l | grep backup_supabase"
ssh "root@$HETZNER_HOST" "echo 'pg_dump version:' && pg_dump --version"
ssh "root@$HETZNER_HOST" "echo 'Timezone:' && date '+%Z %z'"
ssh "root@$HETZNER_HOST" "echo 'Backup dir:' && ls -la /var/backups/supabase/"

echo ""
echo "Backups will run at 4:00 AM Eastern daily."
echo "Dumps stored in /var/backups/supabase/ on $HETZNER_HOST"
echo ""
echo "To run a test backup now:"
echo "  ssh root@$HETZNER_HOST '. $REMOTE_ENV && $REMOTE_SCRIPT'"
echo ""
echo "To check backup status:"
echo "  ssh root@$HETZNER_HOST 'cat /var/backups/supabase/backup.log | tail -20'"
