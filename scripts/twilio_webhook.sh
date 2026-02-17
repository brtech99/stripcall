#!/bin/bash
# twilio_webhook.sh — Toggle Twilio SMS webhook URLs between the new StripCall
# Supabase app and the previous per-phone URLs.
#
# Usage:
#   ./scripts/twilio_webhook.sh status       # Show current webhook config
#   ./scripts/twilio_webhook.sh stripcall    # Save current URLs, switch to Supabase
#   ./scripts/twilio_webhook.sh restore      # Restore each phone's saved URL
#
# The "stripcall" command saves each phone's current URL before switching,
# so "restore" puts each phone back to whatever it was pointing to before.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SECRETS_FILE="$SCRIPT_DIR/config/secrets.sh"
SAVED_URLS_FILE="$SCRIPT_DIR/config/.twilio_saved_urls"

if [ ! -f "$SECRETS_FILE" ]; then
  echo "ERROR: $SECRETS_FILE not found."
  exit 1
fi
source "$SECRETS_FILE"

# ── Webhook URLs ──────────────────────────────────────────────────────────────

STRIPCALL_WEBHOOK="https://wpytorahphbnzgikowgz.supabase.co/functions/v1/receive-sms"

# ── Phone numbers ─────────────────────────────────────────────────────────────

PHONES=(
  "+17542276679:Armorer"
  "+13127577223:Medical"
  "+16504803067:Natloff"
)

# ── Validate credentials ─────────────────────────────────────────────────────

if [ -z "${TWILIO_ACCOUNT_SID:-}" ] || [ -z "${TWILIO_AUTH_TOKEN:-}" ]; then
  echo "ERROR: TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN must be set in secrets.sh"
  exit 1
fi

SID="$TWILIO_ACCOUNT_SID"
TOKEN="$TWILIO_AUTH_TOKEN"
API_BASE="https://api.twilio.com/2010-04-01/Accounts/$SID"

# ── Functions ─────────────────────────────────────────────────────────────────

get_phone_sid() {
  local phone="$1"
  local response
  response=$(curl -s -u "$SID:$TOKEN" \
    "$API_BASE/IncomingPhoneNumbers.json?PhoneNumber=$phone")

  echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
numbers = data.get('incoming_phone_numbers', [])
if numbers:
    print(numbers[0]['sid'])
else:
    print('NOT_FOUND')
"
}

get_current_webhook() {
  local phone_sid="$1"
  local response
  response=$(curl -s -u "$SID:$TOKEN" \
    "$API_BASE/IncomingPhoneNumbers/$phone_sid.json")

  echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('sms_url', 'NOT_SET'))
"
}

set_webhook() {
  local phone_sid="$1"
  local url="$2"
  curl -s -u "$SID:$TOKEN" \
    -X POST \
    "$API_BASE/IncomingPhoneNumbers/$phone_sid.json" \
    -d "SmsUrl=$url" \
    -d "SmsMethod=POST" \
    > /dev/null
}

label_url() {
  local url="$1"
  if [[ "$url" == *"supabase"* ]]; then
    echo "stripcall (new)"
  elif [[ "$url" == *"appspot"* ]]; then
    echo "gcm (old)"
  else
    echo "unknown"
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

ACTION="${1:-}"

if [ -z "$ACTION" ]; then
  echo "Usage: $0 {stripcall|restore|status}"
  echo ""
  echo "  status     - Show current webhook URLs for all phones"
  echo "  stripcall  - Save current URLs, then switch all to Supabase"
  echo "  restore    - Restore each phone to its previously saved URL"
  exit 1
fi

case "$ACTION" in
  status)
    echo "=== Current Twilio Webhook Configuration ==="
    echo ""
    for entry in "${PHONES[@]}"; do
      phone="${entry%%:*}"
      crew="${entry##*:}"
      phone_sid=$(get_phone_sid "$phone")
      if [ "$phone_sid" = "NOT_FOUND" ]; then
        echo "  $crew ($phone): PHONE NOT FOUND IN ACCOUNT"
        continue
      fi
      current=$(get_current_webhook "$phone_sid")
      echo "  $crew ($phone): $(label_url "$current")"
      echo "    URL: $current"
    done
    echo ""
    if [ -f "$SAVED_URLS_FILE" ]; then
      echo "=== Saved URLs (from last 'stripcall' switch) ==="
      echo ""
      while IFS='|' read -r phone crew url; do
        echo "  $crew ($phone): $(label_url "$url")"
        echo "    URL: $url"
      done < "$SAVED_URLS_FILE"
    else
      echo "No saved URLs on file."
    fi
    ;;

  stripcall)
    echo "=== Saving current URLs and switching to StripCall (Supabase) ==="
    echo ""

    # Save current URLs before switching
    > "$SAVED_URLS_FILE"
    for entry in "${PHONES[@]}"; do
      phone="${entry%%:*}"
      crew="${entry##*:}"
      phone_sid=$(get_phone_sid "$phone")
      if [ "$phone_sid" = "NOT_FOUND" ]; then
        echo "  ERROR: $crew ($phone) not found in Twilio account"
        continue
      fi
      current=$(get_current_webhook "$phone_sid")
      echo "${phone}|${crew}|${current}" >> "$SAVED_URLS_FILE"
      echo "  $crew ($phone): saved $current"

      set_webhook "$phone_sid" "$STRIPCALL_WEBHOOK"
      echo "  $crew ($phone): switched to $STRIPCALL_WEBHOOK"
    done
    echo ""
    echo "Done. All phones now point to StripCall."
    echo "Run '$0 restore' to switch back."
    ;;

  restore)
    if [ ! -f "$SAVED_URLS_FILE" ]; then
      echo "ERROR: No saved URLs found. Run '$0 stripcall' first to save current URLs."
      exit 1
    fi

    echo "=== Restoring previous webhook URLs ==="
    echo ""
    while IFS='|' read -r phone crew url; do
      phone_sid=$(get_phone_sid "$phone")
      if [ "$phone_sid" = "NOT_FOUND" ]; then
        echo "  ERROR: $crew ($phone) not found in Twilio account"
        continue
      fi
      set_webhook "$phone_sid" "$url"
      echo "  $crew ($phone): restored to $url"
    done < "$SAVED_URLS_FILE"
    echo ""
    echo "Done. All phones restored to their previous URLs."
    ;;

  *)
    echo "ERROR: Unknown action '$ACTION'. Use: stripcall, restore, or status"
    exit 1
    ;;
esac
