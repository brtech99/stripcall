#!/bin/bash
# Run Maestro smoke tests for StripCall
# Usage: ./run_maestro_tests.sh [flow_name]
# Examples:
#   ./run_maestro_tests.sh              # Run full smoke suite
#   ./run_maestro_tests.sh 01_login     # Run just login flow
#   ./run_maestro_tests.sh --list       # List available flows

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
MAESTRO_DIR="$PROJECT_DIR/.maestro"
FLOWS_DIR="$MAESTRO_DIR/flows"

# Ensure Maestro is in PATH
export PATH="$PATH:$HOME/.maestro/bin"

# Check if Maestro is installed
if ! command -v maestro &> /dev/null; then
    echo "Error: Maestro is not installed."
    echo "Install with: curl -Ls 'https://get.maestro.mobile.dev' | bash"
    exit 1
fi

# Handle arguments
if [ "$1" == "--list" ]; then
    echo "Available Maestro flows:"
    echo "========================"
    ls -1 "$FLOWS_DIR"/*.yaml | xargs -n1 basename | sed 's/.yaml$//'
    exit 0
fi

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "StripCall Maestro Test Runner"
    echo ""
    echo "Usage: ./run_maestro_tests.sh [options] [flow_name]"
    echo ""
    echo "Options:"
    echo "  --list     List available flows"
    echo "  --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./run_maestro_tests.sh              # Run full smoke suite"
    echo "  ./run_maestro_tests.sh 01_login     # Run just login flow"
    echo "  ./run_maestro_tests.sh smoke_suite  # Run full smoke suite explicitly"
    echo ""
    echo "Prerequisites:"
    echo "  - Local Supabase must be running: supabase start"
    echo "  - Database should be reset/seeded: supabase db reset"
    echo "  - iOS Simulator or Android Emulator must be running"
    echo "  - App must be built and installed on the device/emulator"
    exit 0
fi

# Determine which flow to run
FLOW_NAME="${1:-smoke_suite}"
FLOW_FILE="$FLOWS_DIR/${FLOW_NAME}.yaml"

if [ ! -f "$FLOW_FILE" ]; then
    echo "Error: Flow '$FLOW_NAME' not found at $FLOW_FILE"
    echo "Run './run_maestro_tests.sh --list' to see available flows"
    exit 1
fi

echo "============================================"
echo "StripCall Maestro Tests"
echo "============================================"
echo "Flow: $FLOW_NAME"
echo "File: $FLOW_FILE"
echo ""

# Set environment variables for test credentials
export TEST_EMAIL="e2e_superuser@test.com"
export TEST_PASSWORD="TestPassword123!"
export TEST_EMAIL_ARMORER="e2e_armorer1@test.com"
export TEST_EMAIL_MEDICAL="e2e_medical1@test.com"

# Run Maestro
echo "Running Maestro tests..."
maestro test "$FLOW_FILE"

echo ""
echo "============================================"
echo "Maestro tests completed!"
echo "============================================"
