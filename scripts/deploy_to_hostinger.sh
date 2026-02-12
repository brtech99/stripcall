#!/bin/bash

# StripCall Web App Deployment Script for Hostinger
# This script builds and deploys the Flutter web app to stripcall.us
# Usage: ./deploy_to_hostinger.sh

set -e  # Exit on any error

echo "🚀 Starting StripCall Web App Deployment to Hostinger..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BUILD_DIR="build/web"
DEPLOY_DIR="deploy/hostinger"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load configuration
if [ -f "$SCRIPT_DIR/hostinger_config.sh" ]; then
    source "$SCRIPT_DIR/hostinger_config.sh"
else
    echo "Error: scripts/hostinger_config.sh not found. Please create this file with your Hostinger credentials."
    exit 1
fi

# Validate configuration
if [ "$HOSTINGER_FTP_HOST" = "your-ftp-host.hostinger.com" ] || [ "$HOSTINGER_FTP_USER" = "your-ftp-username" ] || [ "$HOSTINGER_FTP_PASS" = "your-ftp-password" ]; then
    echo "Error: Please update scripts/hostinger_config.sh with your actual Hostinger credentials."
    exit 1
fi

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    print_status "Checking dependencies..."

    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi

    if ! command -v lftp &> /dev/null; then
        print_warning "lftp is not installed. Installing via Homebrew..."
        if command -v brew &> /dev/null; then
            brew install lftp
        else
            print_error "Homebrew not found. Please install lftp manually:"
            print_error "  macOS: brew install lftp"
            print_error "  Ubuntu/Debian: sudo apt-get install lftp"
            print_error "  CentOS/RHEL: sudo yum install lftp"
            exit 1
        fi
    fi

    print_success "All dependencies are available"
}

# Check if we're in the right directory
check_directory() {
    if [ ! -f "pubspec.yaml" ]; then
        print_error "pubspec.yaml not found. Please run this script from the Flutter project root."
        exit 1
    fi
}

# Build the web app
build_web_app() {
    print_status "Cleaning previous build..."
    flutter clean

    print_status "Getting dependencies..."
    flutter pub get

    print_status "Building web app for production..."
    flutter build web \
        --dart-define=SUPABASE_URL=https://wpytorahphbnzgikowgz.supabase.co \
        --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndweXRvcmFocGhibnpnaWtvd2d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzYxMjA4ODYsImV4cCI6MjA1MTY5Njg4Nn0.3DFQacxVHHoIeS6wb1GU1GSNQ__Mbmt6SDiZFjwHuWg \
        --dart-define=FIREBASE_API_KEY=AIzaSyDjMXfc5G1dWJ550vrFPpOttgsZDkZV1o4 \
        --dart-define=FIREBASE_APP_ID=1:955423518908:web:f5b75410cb94b99a1660b9 \
        --dart-define=FIREBASE_MESSAGING_SENDER_ID=955423518908 \
        --dart-define=FIREBASE_PROJECT_ID=stripcalls-458912 \
        --dart-define=FIREBASE_AUTH_DOMAIN=stripcalls-458912.firebaseapp.com \
        --dart-define=FIREBASE_STORAGE_BUCKET=stripcalls-458912.firebasestorage.app \
        --dart-define=FIREBASE_VAPID_KEY=BItsPB1Bqqca7WTqn5fLte6N0xcg0C5i_c9yCMit1a02DMW2EA8Zdgaqpg0HD0eAatI01gdiiFjfqIXEOi8xNds \
        --dart-define=FIREBASE_IOS_APP_ID=1:955423518908:ios:11184007abc8b1fa1660b9 \
        --release \
        --base-href "${HOSTINGER_APP_PATH}/"

    if [ ! -d "$BUILD_DIR" ]; then
        print_error "Build failed - $BUILD_DIR not found"
        exit 1
    fi

    print_success "Web app built successfully!"
}

# Prepare deployment directory
prepare_deploy() {
    print_status "Preparing deployment directory..."
    rm -rf "$DEPLOY_DIR"
    mkdir -p "$DEPLOY_DIR"
    cp -r "$BUILD_DIR"/* "$DEPLOY_DIR/"

    # Create .htaccess for proper routing (SPA support) with subdirectory
    cat > "$DEPLOY_DIR/.htaccess" << EOF
RewriteEngine On
RewriteBase ${HOSTINGER_APP_PATH}/

# Handle Flutter web routing
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.html [L]

# Security headers
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"

# Cache static assets
<FilesMatch "\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$">
    ExpiresActive On
    ExpiresDefault "access plus 1 year"
    Header set Cache-Control "public, immutable"
</FilesMatch>

# Gzip compression
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/plain
    AddOutputFilterByType DEFLATE text/html
    AddOutputFilterByType DEFLATE text/xml
    AddOutputFilterByType DEFLATE text/css
    AddOutputFilterByType DEFLATE application/xml
    AddOutputFilterByType DEFLATE application/xhtml+xml
    AddOutputFilterByType DEFLATE application/rss+xml
    AddOutputFilterByType DEFLATE application/javascript
    AddOutputFilterByType DEFLATE application/x-javascript
</IfModule>
EOF

    print_success "Deployment directory prepared"
}

# Deploy to Hostinger via FTP
deploy_to_hostinger() {
    print_status "Deploying to Hostinger via FTP..."

    # Create lftp script
    cat > deploy_script.lftp << EOF
set ssl:verify-certificate no
set ftp:ssl-allow no
open -u $HOSTINGER_FTP_USER,$HOSTINGER_FTP_PASS -p 21 $HOSTINGER_FTP_HOST
cd $HOSTINGER_FTP_PATH
mkdir -p ${HOSTINGER_APP_PATH#/}
cd ${HOSTINGER_APP_PATH#/}
mirror --reverse --delete --verbose $DEPLOY_DIR .
bye
EOF

    # Execute lftp script
    if lftp -f deploy_script.lftp; then
        print_success "Deployment completed successfully!"
    else
        print_error "Deployment failed"
        exit 1
    fi

    # Clean up
    rm -f deploy_script.lftp
}

# Main deployment process
main() {
    print_status "Starting deployment process..."

    check_dependencies
    check_directory
    build_web_app
    prepare_deploy
    deploy_to_hostinger

    print_success "🎉 StripCall web app deployed to https://$HOSTINGER_DOMAIN$HOSTINGER_APP_PATH"
    print_status "The app should be live in a few minutes."
}

# Run main function
main "$@"
