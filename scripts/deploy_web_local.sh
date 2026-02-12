#!/bin/bash

# StripCall Web App Local Deployment Script
# This script builds and deploys the Flutter web app locally
# so you can test it alongside mobile development

set -e  # Exit on any error

echo "🚀 Starting StripCall Web App Local Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WEB_PORT=3000
BUILD_DIR="build/web"
DEPLOY_DIR="deploy/web"

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

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found. Please run this script from the Flutter project root."
    exit 1
fi

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/config/secrets.sh" ]; then
    source "$SCRIPT_DIR/config/secrets.sh"
else
    print_error "scripts/config/secrets.sh not found. Copy from secrets.template.sh and fill in values."
    exit 1
fi

# Clean up any existing processes
print_status "Cleaning up existing processes..."
pkill -f "python3.*$WEB_PORT" || true
pkill -f "python.*$WEB_PORT" || true

# Clean previous build
print_status "Cleaning previous build..."
flutter clean

# Get dependencies
print_status "Getting dependencies..."
flutter pub get

# Build web app
print_status "Building web app..."
flutter build web \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --release

if [ ! -d "$BUILD_DIR" ]; then
    print_error "Build failed - $BUILD_DIR not found"
    exit 1
fi

print_success "Web app built successfully!"

# Create deploy directory
print_status "Setting up deploy directory..."
rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"
cp -r "$BUILD_DIR"/* "$DEPLOY_DIR/"

# Check if Python is available
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    print_error "Python is required but not found. Please install Python to serve the web app."
    exit 1
fi

# Start local server
print_status "Starting local server on port $WEB_PORT..."
print_status "Web app will be available at: http://localhost:$WEB_PORT"
print_status "Press Ctrl+C to stop the server"

# Function to cleanup on exit
cleanup() {
    print_status "Shutting down server..."
    pkill -f "python.*$WEB_PORT" || true
    print_success "Server stopped"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Start the server
cd "$DEPLOY_DIR"
$PYTHON_CMD -m http.server $WEB_PORT

# This line should never be reached due to the trap
print_error "Server stopped unexpectedly"
exit 1
