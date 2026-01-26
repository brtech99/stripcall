#!/bin/bash
# E2E Test Runner for StripCall
# This script works around patrol_cli bugs with OS:latest and test bundle paths

set -e

# Configuration
SIMULATOR_NAME="iPhone 16 Pro"
SIMULATOR_OS="18.5"
SIMULATOR_ID="19B174A1-1DB6-4E9B-BB21-0DD3BBBFC9D5"
SUPABASE_URL="http://127.0.0.1:54321"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"

echo "=== StripCall E2E Test Runner ==="
echo "Simulator: $SIMULATOR_NAME (iOS $SIMULATOR_OS)"
echo "Supabase URL: $SUPABASE_URL"
echo ""

# Ensure simulator is booted
echo "Booting simulator..."
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true

# Build the test app using patrol (with --no-generate-bundle since we have a fixed test_bundle.dart)
echo "Building test app..."
cd "$(dirname "$0")"

# Run patrol build only (we'll execute manually)
~/.pub-cache/bin/patrol test \
  --target integration_test/app_test.dart \
  --no-generate-bundle \
  -d "$SIMULATOR_ID" \
  --dart-define="SUPABASE_URL=$SUPABASE_URL" \
  --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
  2>&1 || true

# Find the xctestrun file
XCTESTRUN=$(ls build/ios_integ/Build/Products/*.xctestrun 2>/dev/null | head -1)
if [ -z "$XCTESTRUN" ]; then
  echo "ERROR: Could not find .xctestrun file. Build may have failed."
  exit 1
fi
echo "Using xctestrun: $XCTESTRUN"

# Run tests manually with correct OS version
RESULT_PATH="build/e2e_test_results_$(date +%s).xcresult"
echo "Running tests..."
cd ios
xcodebuild test-without-building \
  -xctestrun "../$XCTESTRUN" \
  -only-testing "RunnerUITests/RunnerUITests" \
  -destination "platform=iOS Simulator,OS=$SIMULATOR_OS,name=$SIMULATOR_NAME" \
  -destination-timeout 1 \
  -resultBundlePath "../$RESULT_PATH"

echo ""
echo "=== Test Complete ==="
echo "Results: $RESULT_PATH"
