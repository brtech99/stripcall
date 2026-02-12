const https = require("https");

// FCM token must be passed as first argument
const TOKEN = process.argv[2];
if (!TOKEN) {
  console.error("Usage: node test_fcm_web.js <FCM_TOKEN>");
  process.exit(1);
}

console.log("🚀 Testing FCM via web service...");
console.log("📱 Token:", TOKEN.substring(0, 20) + "...");

// Method 1: Try using a simple HTTP request to FCM
const fcmPayload = JSON.stringify({
  to: TOKEN,
  notification: {
    title: "Test from Web Service",
    body: "This is a real FCM notification sent via web! 🎉",
    sound: "default",
  },
  data: {
    type: "test",
    timestamp: new Date().toISOString(),
  },
  priority: "high",
});

const options = {
  hostname: "fcm.googleapis.com",
  port: 443,
  path: "/fcm/send",
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    Authorization: "key=YOUR_SERVER_KEY", // This won't work without a server key
  },
};

console.log("📋 FCM Payload:");
console.log(fcmPayload);
console.log("");
console.log(
  "❌ This approach requires a server key, which we can't get due to org policy.",
);
console.log("");
console.log("💡 Alternative: Use a free FCM testing service");
console.log(
  "1. Go to: https://firebase.google.com/docs/cloud-messaging/js/first-message",
);
console.log("2. Use the Firebase Console to send a test message");
console.log("3. Or use a third-party FCM testing tool");
console.log("");
console.log("🔑 Your FCM token for testing:");
console.log(TOKEN);
