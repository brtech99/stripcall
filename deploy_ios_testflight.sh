#!/bin/bash
#
# Deploy StripCall iOS app to TestFlight
#
# USAGE:
#   ./deploy_ios_testflight.sh              # Build and upload to TestFlight
#
# PREREQUISITES:
#   1. Xcode installed with valid signing certificates
#   2. App Store Connect API key (see setup below)
#   3. App created in App Store Connect with bundle ID: us.stripcall.app.v2
#
# =============================================================================
# FIRST-TIME SETUP: App Store Connect API Key
# =============================================================================
#
# 1. Go to App Store Connect > Users and Access > Keys
# 2. Click "+" to create a new key with "App Manager" access
# 3. Download the .p8 file (you can only download it once!)
# 4. Note the Key ID and Issuer ID shown on the page
# 5. Create a file at ~/.appstoreconnect/api_key.json with:
#
#    {
#      "key_id": "YOUR_KEY_ID",
#      "issuer_id": "YOUR_ISSUER_ID",
#      "key_path": "/path/to/AuthKey_YOURKEYID.p8"
#    }
#
# Alternatively, set environment variables:
#   export APP_STORE_CONNECT_KEY_ID="YOUR_KEY_ID"
#   export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
#   export APP_STORE_CONNECT_KEY_PATH="/path/to/AuthKey.p8"
#
# =============================================================================
# MANAGING TESTFLIGHT TESTERS
# =============================================================================
#
# Internal Testers (up to 100):
#   - Must be App Store Connect users with Admin, App Manager, or Developer role
#   - Add in App Store Connect > Users and Access
#   - They get automatic access to all builds
#
# External Testers (up to 10,000):
#   - Add in App Store Connect > TestFlight > External Groups
#   - Create a group, add emails
#   - First build to external testers requires Beta App Review (usually quick)
#
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
SCHEME="Runner"
WORKSPACE="ios/Runner.xcworkspace"
ARCHIVE_PATH="build/ios/Runner.xcarchive"
IPA_PATH="build/ios/ipa"
EXPORT_OPTIONS_PLIST="ios/ExportOptions.plist"

echo "=== StripCall iOS TestFlight Deployment ==="
echo ""

# Check for API key configuration
API_KEY_JSON="$HOME/.appstoreconnect/api_key.json"
if [ -f "$API_KEY_JSON" ]; then
    KEY_ID=$(cat "$API_KEY_JSON" | grep -o '"key_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    ISSUER_ID=$(cat "$API_KEY_JSON" | grep -o '"issuer_id"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    KEY_PATH=$(cat "$API_KEY_JSON" | grep -o '"key_path"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
elif [ -n "$APP_STORE_CONNECT_KEY_ID" ]; then
    KEY_ID="$APP_STORE_CONNECT_KEY_ID"
    ISSUER_ID="$APP_STORE_CONNECT_ISSUER_ID"
    KEY_PATH="$APP_STORE_CONNECT_KEY_PATH"
else
    echo "ERROR: App Store Connect API key not configured."
    echo ""
    echo "Please create ~/.appstoreconnect/api_key.json or set environment variables."
    echo "See the comments at the top of this script for instructions."
    exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
    echo "ERROR: API key file not found at: $KEY_PATH"
    exit 1
fi

echo "Using API Key: $KEY_ID"
echo ""

# Create ExportOptions.plist if it doesn't exist
if [ ! -f "$EXPORT_OPTIONS_PLIST" ]; then
    echo "Creating ExportOptions.plist..."
    cat > "$EXPORT_OPTIONS_PLIST" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF
fi

# Clean and get dependencies
echo "Step 1/5: Cleaning and getting dependencies..."
flutter clean
flutter pub get

# Build iOS release
echo ""
echo "Step 2/5: Building Flutter iOS release..."
flutter build ios --release

# Archive
echo ""
echo "Step 3/5: Creating Xcode archive..."
rm -rf "$ARCHIVE_PATH"
xcodebuild -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=iOS" \
    archive \
    CODE_SIGN_STYLE=Automatic \
    -allowProvisioningUpdates

# Export IPA
echo ""
echo "Step 4/5: Exporting IPA..."
rm -rf "$IPA_PATH"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$IPA_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$KEY_PATH" \
    -authenticationKeyID "$KEY_ID" \
    -authenticationKeyIssuerID "$ISSUER_ID"

# Find the IPA file
IPA_FILE=$(find "$IPA_PATH" -name "*.ipa" | head -1)
if [ -z "$IPA_FILE" ]; then
    echo "ERROR: IPA file not found in $IPA_PATH"
    exit 1
fi

echo "IPA created: $IPA_FILE"

# Upload to TestFlight
echo ""
echo "Step 5/5: Uploading to TestFlight..."
xcrun altool --upload-app \
    --type ios \
    --file "$IPA_FILE" \
    --apiKey "$KEY_ID" \
    --apiIssuer "$ISSUER_ID"

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Your build has been uploaded to App Store Connect."
echo "It will appear in TestFlight after processing (usually 5-30 minutes)."
echo ""
echo "Manage TestFlight testers at:"
echo "https://appstoreconnect.apple.com/apps"
