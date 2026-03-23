#!/bin/bash
#
# Failover Pre-flight Check
#
# Run before any tournament to verify the failover system is ready.
# Checks backup freshness, auth sync, secondary health, edge functions,
# and deployed app configuration.
#
# Usage: ./scripts/failover_preflight.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config/secrets.sh"

HETZNER_HOST="supabase.stripcall.us"
PRIMARY_URL="$SUPABASE_URL"
SECONDARY_URL="$SUPABASE_SECONDARY_URL"
SECONDARY_KEY="$SUPABASE_SECONDARY_SERVICE_ROLE_KEY"
PRIMARY_ANON_KEY="$SUPABASE_ANON_KEY"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
WARN=0
FAIL=0

check_pass() {
    echo -e "  ${GREEN}[PASS]${NC} $1"
    PASS=$((PASS + 1))
}

check_warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
    WARN=$((WARN + 1))
}

check_fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
    FAIL=$((FAIL + 1))
}

echo "========================================="
echo "  StripCall Failover Pre-flight Check"
echo "  $(date '+%Y-%m-%d %H:%M %Z')"
echo "========================================="
echo ""

# ─── 1. Hetzner SSH connectivity ────────────────────────────────────
echo -e "${BLUE}1. Hetzner Connectivity${NC}"
if ssh -o ConnectTimeout=5 "root@$HETZNER_HOST" "echo ok" > /dev/null 2>&1; then
    check_pass "SSH to $HETZNER_HOST"
else
    check_fail "Cannot SSH to $HETZNER_HOST"
    echo ""
    echo -e "${RED}Cannot proceed without SSH access. Fix connectivity first.${NC}"
    exit 1
fi
echo ""

# ─── 2. Backup freshness ────────────────────────────────────────────
echo -e "${BLUE}2. Backup Freshness${NC}"
TODAY=$(date '+%Y-%m-%d')
LATEST_BACKUP=$(ssh "root@$HETZNER_HOST" "ls -t /var/backups/supabase/*.sql.gz 2>/dev/null | head -1" 2>/dev/null || echo "")

if [ -n "$LATEST_BACKUP" ]; then
    BACKUP_DATE=$(ssh "root@$HETZNER_HOST" "stat -c '%Y' '$LATEST_BACKUP'" 2>/dev/null || echo "0")
    BACKUP_AGE_HOURS=$(( ($(date +%s) - BACKUP_DATE) / 3600 ))

    if [ "$BACKUP_AGE_HOURS" -le 24 ]; then
        check_pass "Latest backup is ${BACKUP_AGE_HOURS}h old ($(basename "$LATEST_BACKUP"))"
    elif [ "$BACKUP_AGE_HOURS" -le 48 ]; then
        check_warn "Latest backup is ${BACKUP_AGE_HOURS}h old — consider running a fresh backup"
    else
        check_fail "Latest backup is ${BACKUP_AGE_HOURS}h old — run backup before tournament"
    fi
else
    check_fail "No backups found on Hetzner"
fi
echo ""

# ─── 3. Auth sync status ────────────────────────────────────────────
echo -e "${BLUE}3. Auth Sync Status${NC}"

# Check cron is installed
CRON_EXISTS=$(ssh "root@$HETZNER_HOST" "crontab -l 2>/dev/null | grep -c sync_auth" 2>/dev/null || echo "0")
if [ "$CRON_EXISTS" -gt 0 ]; then
    check_pass "Auth sync cron is installed"
else
    check_fail "Auth sync cron not installed — run ./scripts/setup_auth_sync_cron.sh"
fi

# Check last sync log
LAST_SYNC=$(ssh "root@$HETZNER_HOST" "tail -1 /var/backups/supabase/auth_sync.log 2>/dev/null" 2>/dev/null || echo "")
if [ -n "$LAST_SYNC" ]; then
    echo "    Last sync: $LAST_SYNC"
else
    check_warn "No auth sync log found — sync may not have run yet"
fi

# Compare user counts
PRIMARY_USERS=$(curl -s "$PRIMARY_URL/rest/v1/users?select=id" \
    -H "apikey: $PRIMARY_ANON_KEY" \
    -H "Authorization: Bearer $PRIMARY_ANON_KEY" \
    -H "Prefer: count=exact" \
    -o /dev/null -w '' -D - 2>/dev/null | grep -i content-range | grep -o '/[0-9]*' | tr -d '/' || echo "?")

SECONDARY_USERS=$(curl -s "$SECONDARY_URL/rest/v1/users?select=id" \
    -H "apikey: $SECONDARY_KEY" \
    -H "Authorization: Bearer $SECONDARY_KEY" \
    -H "Prefer: count=exact" \
    -o /dev/null -w '' -D - 2>/dev/null | grep -i content-range | grep -o '/[0-9]*' | tr -d '/' || echo "?")

echo "    Primary users: $PRIMARY_USERS | Secondary users: $SECONDARY_USERS"
if [ "$PRIMARY_USERS" != "?" ] && [ "$SECONDARY_USERS" != "?" ]; then
    if [ "$PRIMARY_USERS" = "$SECONDARY_USERS" ]; then
        check_pass "User counts match"
    else
        check_warn "User count mismatch ($PRIMARY_USERS vs $SECONDARY_USERS) — run auth sync"
    fi
fi
echo ""

# ─── 4. Secondary API health ────────────────────────────────────────
echo -e "${BLUE}4. Secondary API Health${NC}"
SECONDARY_STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
    "$SECONDARY_URL/rest/v1/crewtypes?select=id&limit=1" \
    -H "apikey: $SECONDARY_KEY" \
    -H "Authorization: Bearer $SECONDARY_KEY" 2>/dev/null || echo "000")

if [ "$SECONDARY_STATUS" = "200" ]; then
    check_pass "Secondary REST API responding (crewtypes query)"
else
    check_fail "Secondary REST API returned $SECONDARY_STATUS"
fi
echo ""

# ─── 5. Edge function health (Hetzner) ──────────────────────────────
echo -e "${BLUE}5. Edge Functions (Hetzner)${NC}"

# Check container is running
CONTAINER_STATUS=$(ssh "root@$HETZNER_HOST" "docker inspect -f '{{.State.Status}}' supabase-edge-functions 2>/dev/null" 2>/dev/null || echo "not found")
if [ "$CONTAINER_STATUS" = "running" ]; then
    check_pass "Edge functions container is running"
else
    check_fail "Edge functions container status: $CONTAINER_STATUS"
fi

# Check keep-alive endpoint
KEEPALIVE_STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
    "$SECONDARY_URL/functions/v1/keep-alive" 2>/dev/null || echo "000")

if [ "$KEEPALIVE_STATUS" = "200" ]; then
    check_pass "keep-alive endpoint responding"
else
    check_fail "keep-alive returned $KEEPALIVE_STATUS — deploy with ./scripts/deploy_edge_functions_hetzner.sh"
fi

# Check critical functions exist on server
CRITICAL_FUNCTIONS="send-sms receive-sms send-fcm-notification go-on-my-way get-app-secrets keep-alive"
MISSING_FUNCS=""
for func in $CRITICAL_FUNCTIONS; do
    EXISTS=$(ssh "root@$HETZNER_HOST" "test -d /opt/supabase/supabase/functions/$func && echo yes || echo no" 2>/dev/null)
    if [ "$EXISTS" != "yes" ]; then
        MISSING_FUNCS="$MISSING_FUNCS $func"
    fi
done

if [ -z "$MISSING_FUNCS" ]; then
    check_pass "All critical function directories present"
else
    check_fail "Missing functions on Hetzner:$MISSING_FUNCS"
fi
echo ""

# ─── 6. Tournament mode status ──────────────────────────────────────
echo -e "${BLUE}6. Tournament Mode${NC}"
TOURNAMENT_MODE=$(ssh "root@$HETZNER_HOST" "cat /opt/stripcall/tournament_mode 2>/dev/null" 2>/dev/null || echo "off")
if [ "$TOURNAMENT_MODE" = "on" ]; then
    check_pass "Tournament mode is ON (daily auth sync)"
else
    check_warn "Tournament mode is OFF — enable with: ssh root@$HETZNER_HOST '/opt/stripcall/tournament_toggle.sh on'"
fi
echo ""

# ─── 7. Table row count comparison ──────────────────────────────────
echo -e "${BLUE}7. Data Sync (Row Counts)${NC}"
TABLES="events crews problems users"

for table in $TABLES; do
    P_COUNT=$(curl -s "$PRIMARY_URL/rest/v1/$table?select=id" \
        -H "apikey: $PRIMARY_ANON_KEY" \
        -H "Authorization: Bearer $PRIMARY_ANON_KEY" \
        -H "Prefer: count=exact" \
        -o /dev/null -w '' -D - 2>/dev/null | grep -i content-range | grep -o '/[0-9]*' | tr -d '/' || echo "?")

    S_COUNT=$(curl -s "$SECONDARY_URL/rest/v1/$table?select=id" \
        -H "apikey: $SECONDARY_KEY" \
        -H "Authorization: Bearer $SECONDARY_KEY" \
        -H "Prefer: count=exact" \
        -o /dev/null -w '' -D - 2>/dev/null | grep -i content-range | grep -o '/[0-9]*' | tr -d '/' || echo "?")

    if [ "$P_COUNT" = "$S_COUNT" ] && [ "$P_COUNT" != "?" ]; then
        echo -e "  ${GREEN}$table${NC}: $P_COUNT = $S_COUNT"
    elif [ "$P_COUNT" = "?" ] || [ "$S_COUNT" = "?" ]; then
        echo -e "  ${YELLOW}$table${NC}: primary=$P_COUNT secondary=$S_COUNT (could not query)"
    else
        echo -e "  ${YELLOW}$table${NC}: primary=$P_COUNT secondary=$S_COUNT (mismatch)"
    fi
done
echo ""

# ─── 8. Deployed app includes secondary URL ─────────────────────────
echo -e "${BLUE}8. Deployed App Configuration${NC}"
# Check the web build for compiled-in secondary URL
WEB_JS="$SCRIPT_DIR/../build/web/main.dart.js"
if [ -f "$WEB_JS" ]; then
    if grep -q "supabase.stripcall.us" "$WEB_JS"; then
        check_pass "Built web app contains secondary URL"
    else
        check_fail "Built web app does NOT contain secondary URL — rebuild with deploy_to_hostinger.sh"
    fi
else
    check_warn "No web build found — cannot verify (run flutter build web first)"
fi
echo ""

# ─── Summary ─────────────────────────────────────────────────────────
echo "========================================="
echo -e "  ${GREEN}PASS: $PASS${NC}  ${YELLOW}WARN: $WARN${NC}  ${RED}FAIL: $FAIL${NC}"
echo ""

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
    echo -e "  ${GREEN}>>> READY FOR TOURNAMENT <<<${NC}"
elif [ "$FAIL" -eq 0 ]; then
    echo -e "  ${YELLOW}>>> READY (with warnings) <<<${NC}"
else
    echo -e "  ${RED}>>> NOT READY — fix failures above <<<${NC}"
fi
echo "========================================="
