#!/bin/bash
#
# Run all E2E integration tests sequentially.
# Resets the database before each test and terminates the app between runs.
#
# Prerequisites:
#   - Docker running
#   - supabase start (already done)
#   - iOS Simulator booted
#   - Maestro installed (for Maestro tests): curl -Ls 'https://get.maestro.mobile.dev' | bash
#
# Usage:
#   ./run_all_tests.sh                    # auto-detect booted simulator
#   ./run_all_tests.sh <SIMULATOR_ID>     # use specific simulator

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

SUPABASE_URL="http://127.0.0.1:54321"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
BUNDLE_ID="com.brianrosen.stripcall"

# Standard tests (run with flutter test)
FLUTTER_TESTS=(
  "integration_test/simple_test.dart"
  "integration_test/app_test.dart"
  "integration_test/create_account_test.dart"
  "integration_test/create_event_test.dart"
  "integration_test/manage_crews_test.dart"
  "integration_test/problem_page_test.dart"
  "integration_test/exhaustive_problem_page_test.dart"
)

# Patrol tests (run with patrol test)
PATROL_TESTS=(
  "integration_test/flow1_setup_and_problem_test.dart"
  "integration_test/sms_workflow_test.dart"
)

# Maestro tests (run with maestro test)
MAESTRO_TESTS=(
  ".maestro/flows/smoke_suite.yaml"
  ".maestro/flows/06_manage_events.yaml"
)

TOTAL_TESTS=$(( ${#FLUTTER_TESTS[@]} + ${#PATROL_TESTS[@]} + ${#MAESTRO_TESTS[@]} ))

# --- Determine simulator ID ---
if [[ -n "${1:-}" ]]; then
  SIM_ID="$1"
else
  SIM_ID=$(xcrun simctl list devices available | grep "(Booted)" | head -1 | sed 's/.*(\([A-F0-9-]*\)).*/\1/')
  if [[ -z "$SIM_ID" ]]; then
    echo "ERROR: No booted simulator found. Boot one first:"
    echo "  xcrun simctl boot \"iPhone 16 Pro\""
    echo "  open -a Simulator"
    exit 1
  fi
fi

echo "========================================"
echo " StripCall E2E Test Suite"
echo "========================================"
echo "Simulator: $SIM_ID"
echo "Flutter tests: ${#FLUTTER_TESTS[@]}"
echo "Patrol tests:  ${#PATROL_TESTS[@]}"
echo "Maestro tests: ${#MAESTRO_TESTS[@]}"
echo "Total:         $TOTAL_TESTS"
echo "========================================"
echo ""

PASSED=()
FAILED=()
SKIPPED=()

reset_db() {
  echo "  Resetting database..."
  if ! supabase db reset 2>&1 | tail -1; then
    echo "  ERROR: Database reset failed"
    return 1
  fi
  return 0
}

kill_app() {
  xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" 2>/dev/null || true
}

run_flutter_test() {
  local TEST_FILE="$1"
  local TEST_NAME
  TEST_NAME=$(basename "$TEST_FILE" .dart)

  echo "----------------------------------------"
  echo "  $TEST_NAME  (flutter)"
  echo "----------------------------------------"

  kill_app
  if ! reset_db; then
    FAILED+=("$TEST_NAME")
    return
  fi

  echo "  Running test..."
  flutter test "$TEST_FILE" --no-pub \
    -d "$SIM_ID" \
    --dart-define="SUPABASE_URL=$SUPABASE_URL" \
    --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
    2>&1 | tee /tmp/stripcall_test_${TEST_NAME}.log \
    | grep -E "^[0-9]|passed|failed|error|All tests|Some tests" || true
  local EXIT_CODE=${PIPESTATUS[0]}

  if [[ $EXIT_CODE -eq 0 ]]; then
    if grep -qi "some tests failed\|FAILED\|test.*failed" /tmp/stripcall_test_${TEST_NAME}.log 2>/dev/null; then
      echo "  FAILED"
      FAILED+=("$TEST_NAME")
    else
      echo "  PASSED"
      PASSED+=("$TEST_NAME")
    fi
  else
    echo "  FAILED (exit code $EXIT_CODE)"
    FAILED+=("$TEST_NAME")
  fi

  kill_app
  echo ""
}

run_patrol_test() {
  local TEST_FILE="$1"
  local TEST_NAME
  TEST_NAME=$(basename "$TEST_FILE" .dart)

  echo "----------------------------------------"
  echo "  $TEST_NAME  (patrol)"
  echo "----------------------------------------"

  kill_app
  if ! reset_db; then
    FAILED+=("$TEST_NAME")
    return
  fi

  echo "  Running test..."
  patrol test \
    --target "$TEST_FILE" \
    --dart-define="SUPABASE_URL=$SUPABASE_URL" \
    --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
    2>&1 | tee /tmp/stripcall_test_${TEST_NAME}.log \
    | grep -E "^[0-9]|passed|failed|error|All tests|Some tests|PASS|FAIL" || true
  local EXIT_CODE=${PIPESTATUS[0]}

  if [[ $EXIT_CODE -eq 0 ]]; then
    if grep -qi "some tests failed\|FAILED\|test.*failed" /tmp/stripcall_test_${TEST_NAME}.log 2>/dev/null; then
      echo "  FAILED"
      FAILED+=("$TEST_NAME")
    else
      echo "  PASSED"
      PASSED+=("$TEST_NAME")
    fi
  else
    echo "  FAILED (exit code $EXIT_CODE)"
    FAILED+=("$TEST_NAME")
  fi

  kill_app
  echo ""
}

run_maestro_test() {
  local TEST_FILE="$1"
  local TEST_NAME
  TEST_NAME=$(basename "$TEST_FILE" .yaml)

  echo "----------------------------------------"
  echo "  $TEST_NAME  (maestro)"
  echo "----------------------------------------"

  # Check if Maestro is installed
  export PATH="$PATH:$HOME/.maestro/bin"
  if ! command -v maestro &>/dev/null; then
    echo "  SKIPPED (maestro not installed)"
    SKIPPED+=("$TEST_NAME")
    echo ""
    return
  fi

  kill_app
  if ! reset_db; then
    FAILED+=("$TEST_NAME")
    return
  fi

  # Set Maestro environment variables
  export TEST_EMAIL="e2e_superuser@test.com"
  export TEST_PASSWORD="TestPassword123!"
  export TEST_EMAIL_ARMORER="e2e_armorer1@test.com"
  export TEST_EMAIL_MEDICAL="e2e_medical1@test.com"
  export TEST_CREW_CHIEF_FIRSTNAME="E2E"
  export TEST_CREW_CHIEF_LASTNAME="Armorer"

  echo "  Running test..."
  maestro test "$TEST_FILE" \
    2>&1 | tee /tmp/stripcall_test_${TEST_NAME}.log \
    | grep -iE "passed|failed|error|PASS|FAIL|Running|Completed" || true
  local EXIT_CODE=${PIPESTATUS[0]}

  if [[ $EXIT_CODE -eq 0 ]]; then
    echo "  PASSED"
    PASSED+=("$TEST_NAME")
  else
    echo "  FAILED (exit code $EXIT_CODE)"
    FAILED+=("$TEST_NAME")
  fi

  kill_app
  echo ""
}

# --- Run Flutter tests ---
for TEST_FILE in "${FLUTTER_TESTS[@]}"; do
  run_flutter_test "$TEST_FILE"
done

# --- Run Patrol tests ---
for TEST_FILE in "${PATROL_TESTS[@]}"; do
  run_patrol_test "$TEST_FILE"
done

# --- Run Maestro tests ---
for TEST_FILE in "${MAESTRO_TESTS[@]}"; do
  run_maestro_test "$TEST_FILE"
done

# --- Summary ---
echo "========================================"
echo " RESULTS"
echo "========================================"

if [[ ${#PASSED[@]} -gt 0 ]]; then
  for t in "${PASSED[@]}"; do
    echo "  PASS  $t"
  done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
  for t in "${FAILED[@]}"; do
    echo "  FAIL  $t"
  done
fi

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  for t in "${SKIPPED[@]}"; do
    echo "  SKIP  $t"
  done
fi

COUNTED=$(( ${#PASSED[@]} + ${#FAILED[@]} ))
echo "========================================"
echo " ${#PASSED[@]} passed, ${#FAILED[@]} failed, ${#SKIPPED[@]} skipped out of $TOTAL_TESTS tests"
echo "========================================"

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo ""
  echo "Test logs are in /tmp/stripcall_test_*.log"
  exit 1
else
  echo ""
  echo "ALL TESTS PASSED"
  exit 0
fi
