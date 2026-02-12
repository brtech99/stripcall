#!/bin/bash

# Load basic configuration
source "$(dirname "$0")/config/secrets.sh"

# Default ports if none provided
PORTS=${@:-8080 8081 8082}

echo "🧹 Cleaning up any existing Flutter web servers..."
for port in $PORTS; do
    lsof -ti:$port | xargs kill -9 2>/dev/null || true
done

echo "🚀 Starting multiple Flutter web app instances..."
echo "📱 Apps will fetch Firebase secrets from Supabase Vault after user login"

# Function to run a single instance
run_instance() {
    local port=$1
    local instance_num=$2

    echo "🚀 Starting instance $instance_num on port $port..."

    flutter run -d chrome --web-port=$port \
      --dart-define=SUPABASE_URL="$SUPABASE_URL" \
      --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" &

    echo "✅ Instance $instance_num started on http://localhost:$port"
}

# Start instances
instance_num=1
for port in $PORTS; do
    run_instance $port $instance_num
    instance_num=$((instance_num + 1))
    sleep 2
done

echo ""
echo "🎉 All instances started!"
echo "Access your instances at:"
instance_num=1
for port in $PORTS; do
    echo "  Instance $instance_num: http://localhost:$port"
    instance_num=$((instance_num + 1))
done
echo ""
echo "Press Ctrl+C to stop all instances"
