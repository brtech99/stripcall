#!/bin/bash

# StripCall iOS Build & Install Script
# Builds the iOS app with production env vars and optionally installs to a connected device.
# Usage: ./scripts/build_ios.sh [install]

set -e

echo "Starting StripCall iOS Build..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load configuration
if [ -f "$SCRIPT_DIR/config/secrets.sh" ]; then
    source "$SCRIPT_DIR/config/secrets.sh"
else
    print_error "scripts/config/secrets.sh not found. Copy from secrets.template.sh and fill in values."
    exit 1
fi

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    print_error "SUPABASE_URL and SUPABASE_ANON_KEY must be set in secrets.sh"
    exit 1
fi

# Build
print_status "Building iOS release..."
flutter build ios --release \
    --dart-define="SUPABASE_URL=$SUPABASE_URL" \
    --dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"

print_success "iOS build complete!"

# Install if requested
if [ "$1" = "install" ]; then
    # Find connected iOS device
    DEVICE_ID=$(flutter devices | grep "mobile" | grep "ios" | grep -v "simulator" | head -1 | sed 's/.*• \([A-Fa-f0-9-]*\) .*/\1/')

    if [ -z "$DEVICE_ID" ]; then
        print_error "No physical iOS device found. Connect your iPhone and try again."
        exit 1
    fi

    print_status "Installing to device $DEVICE_ID..."
    flutter install -d "$DEVICE_ID"
    print_success "Installed to device!"
fi
