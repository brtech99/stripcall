#!/bin/bash

# Script to run multiple web app instances with Firebase configuration
# Usage: ./run_web_multi.sh [port1] [port2] [port3] ...
# Example: ./run_web_multi.sh 8080 8081 8082

# Default ports if none provided
PORTS=${@:-8080 8081 8082}

echo "🧹 Cleaning up any existing Flutter web servers..."
# Kill any existing Flutter web servers on the specified ports
for port in $PORTS; do
    lsof -ti:$port | xargs kill -9 2>/dev/null || true
done
echo "✅ Server cleanup completed"

echo "Setting up Firebase and Supabase environment variables..."

# Function to run a single instance
run_instance() {
    local port=$1
    local instance_num=$2
    
    echo "🚀 Starting instance $instance_num on port $port..."
    
    # Run the Flutter web app with all environment variables passed via --dart-define
    flutter run -d chrome --web-port=$port \
      --dart-define=SUPABASE_URL=https://wpytorahphbnzgikowgz.supabase.co \
      --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndweXRvcmFocGhibnpnaWtvd2d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzYxMjA4ODYsImV4cCI6MjA1MTY5Njg4Nn0.3DFQacxVHHoIeS6wb1GU1GSNQ__Mbmt6SDiZFjwHuWg \
      --dart-define=FIREBASE_API_KEY=AIzaSyDjMXfc5G1dWJ550vrFPpOttgsZDkZV1o4 \
      --dart-define=FIREBASE_APP_ID=1:955423518908:web:f5b75410cb94b99a1660b9 \
      --dart-define=FIREBASE_MESSAGING_SENDER_ID=955423518908 \
      --dart-define=FIREBASE_PROJECT_ID=stripcalls-458912 \
      --dart-define=FIREBASE_AUTH_DOMAIN=stripcalls-458912.firebaseapp.com \
      --dart-define=FIREBASE_STORAGE_BUCKET=stripcalls-458912.firebasestorage.app \
      --dart-define=FIREBASE_VAPID_KEY=BItsPB1Bqqca7WTqn5fLte6N0xcg0C5i_c9yCMit1a02DMW2EA8Zdgaqpg0HD0eAatI01gdiiFjfqIXEOi8xNds \
      --dart-define=FIREBASE_IOS_APP_ID=1:955423518908:ios:11184007abc8b1fa1660b9 &
    
    echo "✅ Instance $instance_num started on http://localhost:$port"
}

# Start instances
instance_num=1
for port in $PORTS; do
    run_instance $port $instance_num
    instance_num=$((instance_num + 1))
    sleep 2  # Small delay between instances
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
echo "💡 Tip: Use different browsers or incognito windows for each instance"
echo "   to test with different users simultaneously."
echo ""
echo "Press Ctrl+C to stop all instances" 