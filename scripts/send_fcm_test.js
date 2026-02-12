const admin = require("firebase-admin");

// FCM token must be passed as first argument
const TOKEN = process.argv[2];
if (!TOKEN) {
  console.error("Usage: node send_fcm_test.js <FCM_TOKEN>");
  process.exit(1);
}

console.log("🚀 Testing Real FCM Notification...");
console.log("📱 Token:", TOKEN.substring(0, 20) + "...");

// Check if service account key exists
const fs = require("fs");
if (!fs.existsSync("./serviceAccountKey.json")) {
  console.log("❌ serviceAccountKey.json not found!");
  console.log("");
  console.log("📋 To get your service account key:");
  console.log(
    "1. Go to Firebase Console → Project Settings → Service Accounts",
  );
  console.log('2. Click "Generate new private key"');
  console.log('3. Save as "serviceAccountKey.json" in this directory');
  console.log("4. Run: npm install firebase-admin");
  console.log("5. Run: node send_fcm_test.js");
  process.exit(1);
}

try {
  // Initialize Firebase Admin SDK
  const serviceAccount = require("./serviceAccountKey.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  console.log("✅ Firebase Admin SDK initialized");

  async function sendNotification() {
    try {
      const message = {
        notification: {
          title: "Test from Node.js",
          body: "This is a real FCM notification sent via Firebase Admin SDK! 🎉",
        },
        token: TOKEN,
        data: {
          type: "test",
          timestamp: new Date().toISOString(),
        },
      };

      console.log("📤 Sending notification...");
      const response = await admin.messaging().send(message);
      console.log("✅ Successfully sent message:", response);
      console.log("📱 Check your device for the notification!");
    } catch (error) {
      console.error("❌ Error sending message:", error.message);
      if (error.code === "messaging/invalid-registration-token") {
        console.log("💡 The FCM token might be invalid or expired");
      } else if (error.code === "messaging/registration-token-not-registered") {
        console.log("💡 The device token is no longer valid");
      }
    }
  }

  sendNotification();
} catch (error) {
  console.error("❌ Error initializing Firebase Admin SDK:", error.message);
  console.log("💡 Make sure your serviceAccountKey.json is valid");
}
