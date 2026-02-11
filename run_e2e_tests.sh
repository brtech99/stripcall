#!/bin/bash
# E2E Test Runner for StripCall
# Runs Patrol, Maestro, and/or Flutter integration tests.
#
# Usage:
#   ./run_e2e_tests.sh              # Run all test suites
#   ./run_e2e_tests.sh smoke        # Run only smoke test (login/logout)
#   ./run_e2e_tests.sh flutter      # Run only Flutter integration test (exhaustive)
#   ./run_e2e_tests.sh maestro      # Run only Maestro smoke suite
#   ./run_e2e_tests.sh --help       # Show this help
#
# Prerequisites:
#   - Docker running
#   - Local Supabase: supabase start && supabase db reset
#   - iOS Simulator booted
#   - For Maestro: app must be running on the simulator first

set -e

cd "$(dirname "$0")"

# Configuration
SUPABASE_URL="http://127.0.0.1:54321"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
FLUTTER_TEST_FILE="integration_test/exhaustive_problem_page_test.dart"
SMOKE_TEST_FILE="integration_test/app_test.dart"
MAESTRO_FLOW=".maestro/flows/smoke_suite.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_help() {
  head -14 "$0" | tail -12 | sed 's/^# //' | sed 's/^#//'
  exit 0
}

# Find a booted simulator
find_simulator() {
  SIMULATOR_ID=$(xcrun simctl list devices booted | grep -oE '[A-F0-9-]{36}' | head -1)
  if [ -z "$SIMULATOR_ID" ]; then
    echo -e "${RED}ERROR: No booted iOS simulator found.${NC}"
    echo "Boot one with: xcrun simctl boot <device-id>"
    echo "Available devices:"
    xcrun simctl list devices available | grep iPhone
    exit 1
  fi
  SIMULATOR_NAME=$(xcrun simctl list devices booted | grep "$SIMULATOR_ID" | sed 's/ (.*//' | xargs)
  echo "Simulator: $SIMULATOR_NAME ($SIMULATOR_ID)"
}

# ─── Smoke Test (login/logout) ───
run_smoke() {
  echo ""
  echo -e "${YELLOW}=== Smoke Test: Login/Logout ===${NC}"
  find_simulator

  flutter test "$SMOKE_TEST_FILE" --no-pub \
    -d "$SIMULATOR_ID" \
    --dart-define="SUPABASE_URL=$SUPABASE_URL" \
    --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
    --dart-define="SKIP_NOTIFICATIONS=true"

  echo -e "${GREEN}=== Smoke Test Complete ===${NC}"
}

# ─── Flutter Integration Test (exhaustive) ───
run_flutter() {
  echo ""
  echo -e "${YELLOW}=== Flutter Integration Test: Exhaustive Problem Page ===${NC}"
  find_simulator

  flutter test "$FLUTTER_TEST_FILE" --no-pub \
    -d "$SIMULATOR_ID" \
    --dart-define="SUPABASE_URL=$SUPABASE_URL" \
    --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
    --dart-define="SKIP_NOTIFICATIONS=true"

  echo -e "${GREEN}=== Flutter Integration Test Complete ===${NC}"
}

# ─── Maestro Smoke Suite ───
run_maestro() {
  echo ""
  echo -e "${YELLOW}=== Maestro Smoke Suite ===${NC}"
  echo "NOTE: The app must already be running on the simulator."
  echo "      If not, launch it first with: ./run_app.sh"
  echo ""

  export PATH="$PATH:$HOME/.maestro/bin"

  if ! command -v maestro &> /dev/null; then
    echo -e "${RED}ERROR: Maestro is not installed.${NC}"
    echo "Install with: curl -Ls 'https://get.maestro.mobile.dev' | bash"
    return 1
  fi

  export TEST_EMAIL="e2e_superuser@test.com"
  export TEST_PASSWORD="TestPassword123!"
  export TEST_EMAIL_ARMORER="e2e_armorer1@test.com"
  export TEST_EMAIL_MEDICAL="e2e_medical1@test.com"
  export TEST_CREW_CHIEF_FIRSTNAME="E2E"
  export TEST_CREW_CHIEF_LASTNAME="Armorer"

  maestro test "$MAESTRO_FLOW"

  echo -e "${GREEN}=== Maestro Smoke Suite Complete ===${NC}"
}

# ─── Main ───
echo "============================================"
echo "  StripCall E2E Test Runner"
echo "============================================"
echo "Supabase URL: $SUPABASE_URL"

case "${1:-all}" in
  smoke)
    run_smoke
    ;;
  flutter)
    run_flutter
    ;;
  maestro)
    run_maestro
    ;;
  all)
    run_smoke
    run_flutter
    run_maestro
    ;;
  --help|-h)
    show_help
    ;;
  *)
    echo -e "${RED}Unknown option: $1${NC}"
    show_help
    ;;
esac

echo ""
echo "============================================"
echo -e "${GREEN}  All requested tests complete!${NC}"
echo "============================================"
