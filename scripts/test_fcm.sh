#!/bin/bash

# Test FCM Notification Script
# This script sends a real FCM notification to your device

echo "🚀 Testing Real FCM Notification..."

# FCM token must be passed as first argument
TOKEN="${1:?Usage: $0 <FCM_TOKEN>}"

# Your Firebase project ID
PROJECT_ID="stripcalls-458912"

echo "📱 Sending to token: ${TOKEN:0:20}..."

# Method 1: Try using Firebase Admin SDK via a simple endpoint
echo "🔧 Method 1: Using Firebase Admin SDK..."

# Create a simple Node.js script to send FCM
cat > temp_fcm_test.js << 'EOF'
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const token = process.argv[2];
const title = process.argv[3] || 'Test Notification';
const body = process.argv[4] || 'This is a real FCM test!';

async function sendNotification() {
  try {
    const message = {
      notification: {
        title: title,
        body: body,
      },
      token: token,
    };

    const response = await admin.messaging().send(message);
    console.log('✅ Successfully sent message:', response);
  } catch (error) {
    console.error('❌ Error sending message:', error);
  }
}

sendNotification();
EOF

echo "📋 To send a real FCM notification:"
echo ""
echo "1. Download your Firebase service account key:"
echo "   - Go to Firebase Console → Project Settings → Service Accounts"
echo "   - Click 'Generate new private key'"
echo "   - Save as 'serviceAccountKey.json' in this directory"
echo ""
echo "2. Install Node.js dependencies:"
echo "   npm install firebase-admin"
echo ""
echo "3. Run the test:"
echo "   node temp_fcm_test.js '$TOKEN' 'Test Title' 'Test Message'"
echo ""
echo "🔑 Your FCM token: $TOKEN"
echo "🏗️  Your Firebase project: $PROJECT_ID"

# Clean up
rm -f temp_fcm_test.js

echo ""
echo "💡 Alternative: Use Firebase CLI to send a test message"
echo "   firebase messaging:send --token '$TOKEN' --message '{\"notification\":{\"title\":\"Test\",\"body\":\"Hello from CLI\"}}'"

echo ""
echo "=========================================="
echo "FIREBASE FUNCTION TESTING"
echo "=========================================="
echo ""
echo "To test your deployed Firebase Function:"
echo "1. Open your StripCall app"
echo "2. Go to Settings menu (gear icon)"
echo "3. Select 'Test Firebase Function'"
echo "4. Check your device for the notification"
echo ""
echo "The Firebase Function URL is:"
echo "https://us-central1-stripcalls-458912.cloudfunctions.net/testNotification"
echo ""
echo "You can also test it directly with curl:"
echo "curl -X POST \\"
echo "  https://us-central1-stripcalls-458912.cloudfunctions.net/testNotification \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"token\": \"YOUR_DEVICE_TOKEN\", \"title\": \"Test\", \"body\": \"Hello from Firebase Function!\"}'"
