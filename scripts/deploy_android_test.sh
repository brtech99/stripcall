#!/bin/bash
#
# Deploy StripCall Android app to Firebase App Distribution for testing
#
# USAGE:
#   ./deploy_android_test.sh                    # Build and deploy debug APK
#   ./deploy_android_test.sh --release          # Build and deploy release APK (requires signing key)
#   ./deploy_android_test.sh "Fixed bug XYZ"    # Deploy with custom release notes
#
# PREREQUISITES:
#   1. Firebase CLI installed: npm install -g firebase-tools
#   2. Logged into Firebase: firebase login
#   3. For release builds: signing key configured (see below)
#
# =============================================================================
# MANAGING TESTERS
# =============================================================================
#
# Add testers by email:
#   firebase appdistribution:testers:add user1@example.com user2@example.com
#
# Create a tester group:
#   firebase appdistribution:groups:create "Beta Testers" beta-testers
#
# Add testers to a group:
#   firebase appdistribution:testers:add --group-alias beta-testers user@example.com
#
# List current testers:
#   firebase appdistribution:testers:list
#
# Remove a tester:
#   firebase appdistribution:testers:remove user@example.com
#
# You can also manage testers in the Firebase Console:
#   https://console.firebase.google.com/project/stripcall/appdistribution
#
# =============================================================================
# RELEASE BUILDS (for Play Store submission)
# =============================================================================
#
# To create a release build, you need a signing key. Create one with:
#
#   keytool -genkey -v -keystore android/app/upload-keystore.jks \
#     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
#
# Then create android/key.properties with:
#
#   storePassword=<your-keystore-password>
#   keyPassword=<your-key-password>
#   keyAlias=upload
#   storeFile=upload-keystore.jks
#
# IMPORTANT: Never commit key.properties or .jks files to git!
#
# =============================================================================

set -e

# Configuration
FIREBASE_APP_ID="1:842118395137:android:5eb39291bffd86295ad700"
TESTER_GROUP="beta-testers"

# Parse arguments
BUILD_TYPE="debug"
RELEASE_NOTES="Test build $(date '+%Y-%m-%d %H:%M')"

while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_TYPE="release"
            shift
            ;;
        *)
            RELEASE_NOTES="$1"
            shift
            ;;
    esac
done

echo "=== StripCall Android Test Deployment ==="
echo "Build type: $BUILD_TYPE"
echo "Release notes: $RELEASE_NOTES"
echo ""

# Build the APK
echo "Building $BUILD_TYPE APK..."
if [ "$BUILD_TYPE" = "release" ]; then
    if [ ! -f "android/key.properties" ]; then
        echo "ERROR: android/key.properties not found. See script comments for setup instructions."
        exit 1
    fi
    flutter build apk --release
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
else
    flutter build apk --debug
    APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
fi

if [ ! -f "$APK_PATH" ]; then
    echo "ERROR: APK not found at $APK_PATH"
    exit 1
fi

echo "APK built: $APK_PATH"
echo ""

# Upload to Firebase App Distribution
echo "Uploading to Firebase App Distribution..."
firebase appdistribution:distribute "$APK_PATH" \
    --app "$FIREBASE_APP_ID" \
    --groups "$TESTER_GROUP" \
    --release-notes "$RELEASE_NOTES"

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Testers in the '$TESTER_GROUP' group will receive an email notification."
echo "They can also access the app at: https://appdistribution.firebase.dev/i/stripcall"
echo ""
echo "Manage testers at: https://console.firebase.google.com/project/stripcall/appdistribution"
