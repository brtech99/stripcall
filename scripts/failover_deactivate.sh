#!/bin/bash
#
# Failover Deactivation (Failback) Script
#
# Run after a tournament when the primary Supabase Cloud has recovered.
# Restores infrastructure to normal operation and reconciles data.
#
# Steps:
#   1. Verify primary is healthy
#   2. Compare key table row counts
#   3. Dump delta from secondary (rows created/modified during outage)
#   4. Generate reconciliation SQL
#   5. Apply to primary (with confirmation)
#   6. Restore Twilio webhooks to primary
#   7. Disable tournament mode
#
# Usage: ./scripts/failover_deactivate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config/secrets.sh"

HETZNER_HOST="supabase.stripcall.us"
PRIMARY_URL="$SUPABASE_URL"
PRIMARY_ANON_KEY="$SUPABASE_ANON_KEY"
SECONDARY_URL="$SUPABASE_SECONDARY_URL"
SECONDARY_KEY="$SUPABASE_SECONDARY_SERVICE_ROLE_KEY"

TWILIO_SID="$TWILIO_ACCOUNT_SID"
TWILIO_TOKEN="$TWILIO_AUTH_TOKEN"
TWILIO_PHONES=("+17542276679" "+13127577223" "+16504803067")
PRIMARY_WEBHOOK_URL="$PRIMARY_URL/functions/v1/receive-sms"

RECONCILE_DIR="/tmp/stripcall_failback_$(date '+%Y%m%d_%H%M%S')"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "  StripCall FAILBACK (Deactivation)"
echo "  $(date '+%Y-%m-%d %H:%M %Z')"
echo "========================================="
echo ""

# ─── 1. Verify primary is healthy ───────────────────────────────────
echo -e "${BLUE}1. Verifying primary health...${NC}"

PRIMARY_STATUS=$(curl -s -o /dev/null -w '%{http_code}' \
    "$PRIMARY_URL/rest/v1/crewtypes?select=id&limit=1" \
    -H "apikey: $PRIMARY_ANON_KEY" \
    -H "Authorization: Bearer $PRIMARY_ANON_KEY" 2>/dev/null || echo "000")

if [ "$PRIMARY_STATUS" = "200" ]; then
    echo -e "  ${GREEN}Primary REST API is healthy${NC}"
else
    echo -e "  ${RED}Primary returned $PRIMARY_STATUS — not ready for failback${NC}"
    exit 1
fi
echo ""

# ─── 2. Compare row counts ──────────────────────────────────────────
echo -e "${BLUE}2. Comparing row counts (secondary vs primary)...${NC}"
echo ""
TABLES="events crews problems users crewmembers sms_messages"

printf "  %-20s %10s %10s %10s\n" "Table" "Primary" "Secondary" "Delta"
printf "  %-20s %10s %10s %10s\n" "-----" "-------" "---------" "-----"

RECONCILE_NEEDED=false

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

    if [ "$P_COUNT" != "?" ] && [ "$S_COUNT" != "?" ]; then
        DELTA=$((S_COUNT - P_COUNT))
        if [ "$DELTA" -gt 0 ]; then
            printf "  %-20s %10s %10s ${YELLOW}%10s${NC}\n" "$table" "$P_COUNT" "$S_COUNT" "+$DELTA"
            RECONCILE_NEEDED=true
        elif [ "$DELTA" -lt 0 ]; then
            printf "  %-20s %10s %10s ${RED}%10s${NC}\n" "$table" "$P_COUNT" "$S_COUNT" "$DELTA"
        else
            printf "  %-20s %10s %10s ${GREEN}%10s${NC}\n" "$table" "$P_COUNT" "$S_COUNT" "0"
        fi
    else
        printf "  %-20s %10s %10s %10s\n" "$table" "$P_COUNT" "$S_COUNT" "?"
    fi
done
echo ""

# ─── 3. Dump delta from secondary ───────────────────────────────────
if [ "$RECONCILE_NEEDED" = true ]; then
    echo -e "${BLUE}3. Dumping delta data from secondary...${NC}"
    mkdir -p "$RECONCILE_DIR"

    # Dump tables that have more rows on secondary
    # This is a simplified approach — for production, you'd compare by timestamp
    ssh "root@$HETZNER_HOST" "
        export PGPASSWORD='$SUPABASE_SECONDARY_DB_PASS'
        for table in $TABLES; do
            pg_dump -h localhost -U postgres -d postgres \
                --data-only --table=\"public.\$table\" \
                --inserts --on-conflict-do-nothing \
                2>/dev/null || true
        done
    " > "$RECONCILE_DIR/delta_dump.sql" 2>/dev/null || true

    if [ -s "$RECONCILE_DIR/delta_dump.sql" ]; then
        echo -e "  ${GREEN}Delta dump saved to $RECONCILE_DIR/delta_dump.sql${NC}"
        echo "  Size: $(wc -c < "$RECONCILE_DIR/delta_dump.sql" | tr -d ' ') bytes"
        echo ""
        echo -e "  ${YELLOW}Review the dump before applying to primary.${NC}"
        echo "  To apply manually:"
        echo "    PGPASSWORD='$SUPABASE_DB_PASS' psql -h $SUPABASE_DB_HOST -U postgres -d postgres < $RECONCILE_DIR/delta_dump.sql"
        echo ""
        read -p "  Apply reconciliation SQL to primary now? (yes/no): " APPLY
        if [ "$APPLY" = "yes" ]; then
            PGPASSWORD="$SUPABASE_DB_PASS" psql \
                -h "$SUPABASE_DB_HOST" -U postgres -d postgres \
                < "$RECONCILE_DIR/delta_dump.sql" 2>&1 || true
            echo -e "  ${GREEN}Reconciliation applied${NC}"
        else
            echo "  Skipped — apply manually when ready."
        fi
    else
        echo -e "  ${YELLOW}No delta data to reconcile${NC}"
    fi
else
    echo -e "${BLUE}3. No reconciliation needed — row counts match${NC}"
fi
echo ""

# ─── 4. Restore Twilio webhooks ─────────────────────────────────────
echo -e "${BLUE}4. Restoring Twilio webhook URLs to primary...${NC}"

for phone in "${TWILIO_PHONES[@]}"; do
    PHONE_SID=$(curl -s -u "$TWILIO_SID:$TWILIO_TOKEN" \
        "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/IncomingPhoneNumbers.json?PhoneNumber=$phone" \
        | grep -o '"sid":"PN[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$PHONE_SID" ]; then
        curl -s -X POST \
            "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_SID/IncomingPhoneNumbers/$PHONE_SID.json" \
            -u "$TWILIO_SID:$TWILIO_TOKEN" \
            --data-urlencode "SmsUrl=$PRIMARY_WEBHOOK_URL" > /dev/null

        echo -e "  ${GREEN}$phone → $PRIMARY_WEBHOOK_URL${NC}"
    else
        echo -e "  ${RED}Could not find SID for $phone${NC}"
    fi
done
echo ""

# ─── 5. Disable tournament mode ─────────────────────────────────────
echo -e "${BLUE}5. Disabling tournament mode...${NC}"
ssh "root@$HETZNER_HOST" "/opt/stripcall/tournament_toggle.sh off" 2>/dev/null || true
echo -e "  ${GREEN}Tournament mode disabled${NC}"
echo ""

# ─── Summary ─────────────────────────────────────────────────────────
echo "========================================="
echo -e "  ${GREEN}FAILBACK COMPLETE${NC}"
echo "========================================="
echo ""
echo "Restored to normal operation:"
echo "  - App reads/writes go to primary (via health checks)"
echo "  - Twilio webhooks point to primary"
echo "  - Tournament mode disabled (weekly auth sync)"
if [ -d "$RECONCILE_DIR" ]; then
    echo ""
    echo "Reconciliation data saved at: $RECONCILE_DIR"
fi
