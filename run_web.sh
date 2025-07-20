#!/bin/bash

# Script to run web app with Firebase configuration
# Usage: ./run_web.sh

echo "🧹 Cleaning up any existing Flutter web server..."
# Kill any existing Flutter web server on port 8080
lsof -ti:8080 | xargs kill -9 2>/dev/null || true
echo "✅ Server cleanup completed"

echo "Setting up Firebase and Supabase environment variables..."

echo "✅ Firebase and Supabase environment variables set"
echo "Running Flutter web app..."

# Run the Flutter web app with all environment variables passed via --dart-define
flutter run -d chrome --web-port=8080 \
  --dart-define=SUPABASE_URL=https://wpytorahphbnzgikowgz.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndweXRvcmFocGhibnpnaWtvd2d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzYxMjA4ODYsImV4cCI6MjA1MTY5Njg4Nn0.3DFQacxVHHoIeS6wb1GU1GSNQ__Mbmt6SDiZFjwHuWg \
  --dart-define=FIREBASE_API_KEY=AIzaSyDjMXfc5G1dWJ550vrFPpOttgsZDkZV1o4 \
  --dart-define=FIREBASE_APP_ID=1:955423518908:web:f5b75410cb94b99a1660b9 \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=955423518908 \
  --dart-define=FIREBASE_PROJECT_ID=stripcalls-458912 \
  --dart-define=FIREBASE_AUTH_DOMAIN=stripcalls-458912.firebaseapp.com \
  --dart-define=FIREBASE_STORAGE_BUCKET=stripcalls-458912.firebasestorage.app \
  --dart-define=FIREBASE_VAPID_KEY=BItsPB1Bqqca7WTqn5fLte6N0xcg0C5i_c9yCMit1a02DMW2EA8Zdgaqpg0HD0eAatI01gdiiFjfqIXEOi8xNds \
  --dart-define=FIREBASE_IOS_APP_ID=1:955423518908:ios:11184007abc8b1fa1660b9 