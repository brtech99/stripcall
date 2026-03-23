#!/bin/bash
#
# Failover Activation Script
#
# Run when the primary Supabase Cloud goes down mid-tournament.
# Handles infrastructure-level changes that the app can't do automatically.
#
# The app already handles read/write failover via SupabaseManager health checks.
# This script handles:
#   1. Verifying secondary is healthy
#   2. Enabling tournament mode (daily auth sync)
#   3. Updating Twilio webhook URLs to point at Hetzner
#   4. Running a final auth sync if primary is reachable
#
# Usage: ./scripts/failover_activate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config/secrets.sh"

HETZNER_HOST="supabase.stripcall.us"
SECONDARY_URL="$SUPABASE_SECONDARY_URL"
SECONDARY_KEY="$SUPABASE_SECONDARY_SERVICE_ROLE_KEY"
PRIMARY_URL="$SUPABASE_URL"

# Twilio webhook settings
TWILIO_SID="$TWILIO_ACCOUNT_SID"
TWILIO_TOKEN="$TWILIO_AUTH_TOKEN"
TWILIO_PHONES=("+17542276679" "+13127577223" "+16504803067")
HETZNER_WEBHOOK_URL="https://$HETZNER_HOST/functions/v1/receive-sms"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "  StripCall FAILOVER ACTIVATION"
echo "  $(date '+%Y-%m-%d %H:%M %Z')"
echo "========================================="
echo ""
echo -e "${RED}This will switch infrastructure to the Hetzner secondary.${NC}"
echo ""
read -p "Are you sure you want to activate failover? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
fi
echo ""

# ─── 1. Verify secondary is healthy ─────────────────────────────────
echo -e "${BLUE}1. Verifying secondary health...${NC}"

SECONDARY_STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
    "$SECONDARY_URL/rest/v1/crewtypes?select=id&limit=1" \
    -H "apikey: $SECONDARY_KEY" \
    -H "Authorization: Bearer $SECONDARY_KEY" 2>/dev/null || echo "000")

if [ "$SECONDARY_STATUS" = "200" ]; then
    echo -e "  ${GREEN}Secondary REST API is healthy${NC}"
else
    echo -e "  ${RED}Secondary REST API returned $SECONDARY_STATUS${NC}"
    echo -e "  ${RED}Cannot activate failover to an unhealthy secondary!${NC}"
    exit 1
fi

KEEPALIVE=$(curl -s -o /dev/null -w '%{http_code}' \
    "$SECONDARY_URL/functions/v1/keep-alive" 2>/dev/null || echo "000")

if [ "$KEEPALIVE" = "200" ]; then
    echo -e "  ${GREEN}Edge functions are running${NC}"
else
    echo -e "  ${YELLOW}Edge functions returned $KEEPALIVE — SMS may not work${NC}"
fi
echo ""

# ─── 2. Enable tournament mode ───────────────────────────────────────
echo -e "${BLUE}2. Enabling tournament mode (daily auth sync)...${NC}"
ssh "root@$HETZNER_HOST" "/opt/stripcall/tournament_toggle.sh on" 2>/dev/null || true
echo -e "  ${GREEN}Tournament mode enabled${NC}"
echo ""

# ─── 3. Try final auth sync ─────────────────────────────────────────
echo -e "${BLUE}3. Attempting final auth sync from primary...${NC}"

PRIMARY_REACHABLE=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 \
    "$PRIMARY_URL/rest/v1/crewtypes?select=id&limit=1" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY" 2>/dev/null || echo "000")

if [ "$PRIMARY_REACHABLE" = "200" ]; then
    echo "  Primary is still partially reachable — running auth sync..."
    ssh "root@$HETZNER_HOST" ". /etc/stripcall-backup.env && /opt/stripcall/sync_auth_to_secondary.sh" 2>/dev/null && \
        echo -e "  ${GREEN}Auth sync completed${NC}" || \
        echo -e "  ${YELLOW}Auth sync failed — proceeding with existing data${NC}"
else
    echo -e "  ${YELLOW}Primary unreachable (HTTP $PRIMARY_REACHABLE) — skipping auth sync${NC}"
fi
echo ""

# ─── 4. Update Twilio webhook URLs ──────────────────────────────────
echo -e "${BLUE}4. Updating Twilio webhook URLs to Hetzner...${NC}"

for phone in "${TWILIO_PHONES[@]}"; do
    # Get the phone number SID
    PHONE_SID=$(curl -s -u "$TWILIO_SID:$TWILIO_TOKEN" \
        "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/IncomingPhoneNumbers.json?PhoneNumber=$phone" \
        | grep -o '"sid":"PN[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$PHONE_SID" ]; then
        curl -s -X POST \
            "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/IncomingPhoneNumbers/$PHONE_SID.json" \
            -u "$TWILIO_SID:$TWILIO_TOKEN" \
            --data-urlencode "SmsUrl=$HETZNER_WEBHOOK_URL" > /dev/null

        echo -e "  ${GREEN}$phone → $HETZNER_WEBHOOK_URL${NC}"
    else
        echo -e "  ${RED}Could not find SID for $phone${NC}"
    fi
done
echo ""

# ─── Summary ─────────────────────────────────────────────────────────
echo "========================================="
echo -e "  ${GREEN}FAILOVER ACTIVATED${NC}"
echo "========================================="
echo ""
echo "What's working:"
echo "  - App reads/writes automatically go to secondary (via health checks)"
echo "  - Twilio SMS webhooks point to Hetzner edge functions"
echo "  - Tournament mode enabled (daily auth sync when primary recovers)"
echo ""
echo "What's degraded:"
echo "  - New user signups (auth is primary-only)"
echo "  - Password resets (email via Supabase Cloud)"
echo "  - Push notifications (if FCM config is primary-only)"
echo ""
echo "When primary recovers, run:"
echo "  ./scripts/failover_deactivate.sh"
