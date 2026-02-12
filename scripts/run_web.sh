#!/bin/bash

# Load basic configuration
source "$(dirname "$0")/config/secrets.sh"

echo "🧹 Cleaning up any existing Flutter web server..."
lsof -ti:8080 | xargs kill -9 2>/dev/null || true

echo "🚀 Starting Flutter web app..."
echo "📱 App will fetch Firebase secrets from Supabase Vault after user login"

# Pass only Supabase credentials - Firebase will come from Vault
flutter run -d chrome --web-port=8080 \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
