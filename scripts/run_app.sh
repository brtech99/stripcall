#!/bin/bash

# Load basic configuration
source "$(dirname "$0")/config/secrets.sh"

echo "🚀 Starting Flutter app..."
echo "📱 App will fetch Firebase secrets from Supabase Vault after user login"

# Simple startup - only Supabase info needed
flutter run -v \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=SUPABASE_SECONDARY_URL="$SUPABASE_SECONDARY_URL" \
  --dart-define=SUPABASE_SECONDARY_SERVICE_ROLE_KEY="$SUPABASE_SECONDARY_SERVICE_ROLE_KEY"
