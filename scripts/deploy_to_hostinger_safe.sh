#!/bin/bash

# StripCall Web App Safe Deployment Script for Hostinger
# This script builds and deploys the Flutter web app to stripcall.us/app
# Usage: ./deploy_to_hostinger_safe.sh

set -e  # Exit on any error

echo "🚀 Starting StripCall Web App Safe Deployment to Hostinger..."

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
if [ -f "$SCRIPT_DIR/config/secrets.sh" ]; then
    source "$SCRIPT_DIR/config/secrets.sh"
else
    echo "Error: scripts/config/secrets.sh not found. Copy from secrets.template.sh and fill in values."
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
        --dart-define=SUPABASE_URL="$SUPABASE_URL" \
        --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
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

# Deploy to Hostinger via FTP (Safe version)
deploy_to_hostinger() {
    print_status "Deploying to Hostinger via FTP (Safe Mode)..."

    # Create lftp script (without --delete flag)
    cat > deploy_script.lftp << EOF
set ssl:verify-certificate no
set ftp:ssl-allow no
open -u $HOSTINGER_FTP_USER,$HOSTINGER_FTP_PASS -p 21 $HOSTINGER_FTP_HOST
cd $HOSTINGER_FTP_PATH
mkdir -p ${HOSTINGER_APP_PATH#/}
cd ${HOSTINGER_APP_PATH#/}
mirror --reverse --verbose $DEPLOY_DIR .
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
    print_status "Starting safe deployment process..."

    check_dependencies
    check_directory
    build_web_app
    prepare_deploy
    deploy_to_hostinger

    print_success "🎉 StripCall web app deployed to https://$HOSTINGER_DOMAIN$HOSTINGER_APP_PATH"
    print_status "The app should be live in a few minutes."
    print_warning "Note: This was a safe deployment (no files were deleted)"
}

# Run main function
main "$@"
