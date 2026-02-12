#!/bin/bash

# StripCall Web App Deployment Script for Hostinger (rsync version)
# This script builds and deploys the Flutter web app to stripcall.us using rsync
# Usage: ./deploy_to_hostinger_rsync.sh

set -e  # Exit on any error

echo "🚀 Starting StripCall Web App Deployment to Hostinger (rsync)..."

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

    if ! command -v rsync &> /dev/null; then
        print_error "rsync is not installed. Please install it:"
        print_error "  macOS: brew install rsync"
        print_error "  Ubuntu/Debian: sudo apt-get install rsync"
        print_error "  CentOS/RHEL: sudo yum install rsync"
        exit 1
    fi

    print_success "All dependencies are available"
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

# Deploy to Hostinger via rsync
deploy_to_hostinger() {
    print_status "Deploying to Hostinger via rsync..."

    # Construct rsync command
    RSYNC_CMD="rsync -avz --delete --progress"

    if [ "$HOSTINGER_VERBOSE_UPLOAD" = "true" ]; then
        RSYNC_CMD="$RSYNC_CMD -v"
    fi

    # Add SSH options for better compatibility
    RSYNC_CMD="$RSYNC_CMD -e 'ssh -o StrictHostKeyChecking=no -p 21'"

    # Execute rsync
    if $RSYNC_CMD "$DEPLOY_DIR/" "$HOSTINGER_FTP_USER@$HOSTINGER_FTP_HOST:$HOSTINGER_FTP_PATH${HOSTINGER_APP_PATH}/"; then
        print_success "Deployment completed successfully!"
    else
        print_error "Deployment failed"
        exit 1
    fi
}

# Main deployment process
main() {
    print_status "Starting deployment process..."

    check_dependencies
    build_web_app
    prepare_deploy
    deploy_to_hostinger

    print_success "🎉 StripCall web app deployed to https://$HOSTINGER_DOMAIN$HOSTINGER_APP_PATH"
    print_status "The app should be live in a few minutes."
}

# Run main function
main "$@"
