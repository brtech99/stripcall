#!/bin/bash
# setup_auth_sync_cron.sh — Install the auth sync cron job on the Hetzner server.
#
# Usage:
#   1. Ensure scripts/config/secrets.sh has all DB credentials (primary + secondary)
#   2. Run: ./scripts/setup_auth_sync_cron.sh
#
# This will:
#   - Copy sync_auth_to_secondary.sh to the Hetzner server
#   - Add secondary DB credentials to the env file
#   - Install the cron job (4:05 AM Eastern daily — 5 min after backup)
#   - Copy the tournament toggle script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SECRETS_FILE="$SCRIPT_DIR/config/secrets.sh"

# Load secrets
if [ ! -f "$SECRETS_FILE" ]; then
  echo "ERROR: $SECRETS_FILE not found."
  exit 1
fi
source "$SECRETS_FILE"

# Validate required variables
for var in SUPABASE_DB_HOST SUPABASE_DB_PASS SUPABASE_SECONDARY_DB_PASS; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: $var is not set in secrets.sh"
    exit 1
  fi
done

HETZNER_HOST="supabase.stripcall.us"
REMOTE_SCRIPT="/opt/stripcall/sync_auth_to_secondary.sh"
REMOTE_TOGGLE="/opt/stripcall/tournament_toggle.sh"
REMOTE_ENV="/etc/stripcall-backup.env"

echo "=== Setting up auth sync on $HETZNER_HOST ==="

# 1. Copy scripts to server
echo "--- Copying scripts ---"
scp "$SCRIPT_DIR/sync_auth_to_secondary.sh" "root@$HETZNER_HOST:$REMOTE_SCRIPT"
scp "$SCRIPT_DIR/tournament_toggle.sh" "root@$HETZNER_HOST:$REMOTE_TOGGLE"
ssh "root@$HETZNER_HOST" "chmod +x $REMOTE_SCRIPT $REMOTE_TOGGLE"

# 2. Append secondary DB credentials to env file (if not already there)
echo "--- Updating credentials ---"
ssh "root@$HETZNER_HOST" "
  if ! grep -q SUPABASE_SECONDARY_DB_HOST $REMOTE_ENV 2>/dev/null; then
    cat >> $REMOTE_ENV << 'ENVEOF'

# Secondary DB (self-hosted Supabase on this server)
export SUPABASE_SECONDARY_DB_HOST=${SUPABASE_SECONDARY_DB_HOST:-localhost}
export SUPABASE_SECONDARY_DB_PORT=${SUPABASE_SECONDARY_DB_PORT:-5432}
export SUPABASE_SECONDARY_DB_NAME=${SUPABASE_SECONDARY_DB_NAME:-postgres}
export SUPABASE_SECONDARY_DB_USER=${SUPABASE_SECONDARY_DB_USER:-postgres}
export SUPABASE_SECONDARY_DB_PASS=$SUPABASE_SECONDARY_DB_PASS
ENVEOF
    echo 'Secondary DB credentials added'
  else
    echo 'Secondary DB credentials already present'
  fi
"

# 3. Install cron job — runs at 4:05 AM daily (5 min after backup)
# The script itself decides whether to run (Wednesday only, unless tournament mode)
CRON_LINE="5 4 * * * . $REMOTE_ENV && $REMOTE_SCRIPT >> /var/backups/supabase/cron.log 2>&1"

echo "--- Installing cron job ---"
ssh "root@$HETZNER_HOST" "(crontab -l 2>/dev/null | grep -v 'sync_auth_to_secondary'; echo '$CRON_LINE') | crontab -"

# 4. Create dump directory
ssh "root@$HETZNER_HOST" "mkdir -p /var/backups/supabase/auth_sync"

# 5. Verify
echo ""
echo "=== Setup complete ==="
echo ""
ssh "root@$HETZNER_HOST" "echo 'Cron entries:' && crontab -l | grep -E 'backup_supabase|sync_auth'"
echo ""
echo "Auth sync runs at 4:05 AM Eastern daily."
echo "  - Normal weeks: only syncs on Wednesday"
echo "  - Tournament weeks: syncs every day"
echo ""
echo "To activate tournament mode (daily sync):"
echo "  ssh root@$HETZNER_HOST '/opt/stripcall/tournament_toggle.sh on'"
echo ""
echo "To deactivate tournament mode:"
echo "  ssh root@$HETZNER_HOST '/opt/stripcall/tournament_toggle.sh off'"
echo ""
echo "To run a test sync now:"
echo "  ssh root@$HETZNER_HOST '. $REMOTE_ENV && $REMOTE_SCRIPT'"
echo ""
echo "To check sync status:"
echo "  ssh root@$HETZNER_HOST 'tail -20 /var/backups/supabase/auth_sync.log'"
