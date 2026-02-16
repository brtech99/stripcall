// Firebase configuration for web
const firebaseConfig = {
  apiKey: "AIzaSyBFzrzdIKWfCt-MOx-EixuhRaLC15iZPSo",
  authDomain: "stripcall.firebaseapp.com",
  databaseURL: "https://stripcall.firebaseio.com",
  projectId: "stripcall",
  storageBucket: "stripcall.firebasestorage.app",
  messagingSenderId: "842118395137",
  appId: "1:842118395137:web:fd1b37f5144e69d25ad700",
  measurementId: "G-9HZVBN70WK",
};

// VAPID key for push notifications
const vapidKey =
  "BNpNj35JLAXYGoUHWB7UPCUBwDL29f7-4o91fxEcfHHrXnkIaxJPLDH9wOhA6H5ZWUIvDNbnSyspkLoQHDP9sNQ";

// Convert VAPID key to Uint8Array
function urlBase64ToUint8Array(base64String) {
  try {
    const cleanBase64 = base64String.replace(/\s/g, "");
    const padding = "=".repeat((4 - (cleanBase64.length % 4)) % 4);
    const base64 = (cleanBase64 + padding)
      .replace(/-/g, "+")
      .replace(/_/g, "/");

    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  } catch (error) {
    console.error("Error converting VAPID key:", error);
    throw new Error("Invalid VAPID key format");
  }
}

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

// Initialize Firebase Cloud Messaging
const messaging = firebase.messaging();

// Register service worker
let firebaseSWRegistration = null;
if ("serviceWorker" in navigator) {
  navigator.serviceWorker
    .register("/firebase-messaging-sw.js")
    .then(function (registration) {
      console.log("Service Worker registered with scope:", registration.scope);
      firebaseSWRegistration = registration;
    })
    .catch(function (err) {
      console.log("Service Worker registration failed:", err);
    });
} else {
  console.log("Service Worker not supported");
}

// Function to request permission and get token
function requestPermissionAndToken() {
  return Notification.requestPermission()
    .then(function (permission) {
      console.log("Notification permission:", permission);
      if (permission === "granted") {
        console.log("Requesting FCM token...");

        return messaging
          .getToken({ vapidKey: vapidKey })
          .then(function (token) {
            console.log("FCM token obtained successfully");
            window.fcmToken = token;
            return token;
          })
          .catch(function (error) {
            console.error("FCM token error:", error);
            console.error(
              "This may indicate an invalid VAPID key or messaging configuration",
            );
            window.fcmToken = null;
            return null;
          });
      } else {
        console.log("Notification permission denied");
        window.fcmToken = null;
        return null;
      }
    })
    .catch(function (err) {
      console.log("Error requesting permission:", err);
      window.fcmToken = null;
      return null;
    });
}

// Initialize notifications - to be called by Flutter after login
window.initializeNotifications = function () {
  console.log("Initializing notifications after login...");
  return requestPermissionAndToken();
};

// Handle foreground messages
messaging.onMessage((payload) => {
  console.log("Message received in foreground:", payload);
  showNotification(payload);
});

function showNotification(payload) {
  const notificationTitle =
    payload.data?.title || payload.notification?.title || "New Message";
  const notificationOptions = {
    body: payload.data?.body || payload.notification?.body || "",
    icon: "/app/icons/Icon-192.png",
    badge: "/app/icons/Icon-192.png",
    tag: "stripcall-notification",
    requireInteraction: true,
    actions: [
      {
        action: "open",
        title: "Open",
      },
      {
        action: "close",
        title: "Close",
      },
    ],
  };

  if (firebaseSWRegistration && "Notification" in window) {
    firebaseSWRegistration.showNotification(
      notificationTitle,
      notificationOptions,
    );
  } else if ("serviceWorker" in navigator && "Notification" in window) {
    navigator.serviceWorker.ready.then(function (registration) {
      registration.showNotification(notificationTitle, notificationOptions);
    });
  }
}

// Function to expose FCM token to Dart
window.getFCMToken = function () {
  if (!window.fcmToken) {
    // Check if notification permission is granted first
    if (Notification.permission !== "granted") {
      console.log("Notification permission not granted, cannot get FCM token");
      return Promise.resolve(null);
    }

    return messaging
      .getToken({ vapidKey: vapidKey })
      .then(function (token) {
        console.log("FCM token obtained:", token ? "success" : "failed");
        window.fcmToken = token;
        return token;
      })
      .catch(function (error) {
        console.error("Error getting FCM token:", error);
        console.error("VAPID key being used:", vapidKey);
        return null;
      });
  }
  return Promise.resolve(window.fcmToken);
};

// Simple function to request notification permission
window.requestNotificationPermission = function () {
  if (Notification.permission === "default") {
    return Notification.requestPermission()
      .then(function (permission) {
        console.log("Permission request result:", permission);
        return permission;
      })
      .catch(function (error) {
        console.log("Error requesting permission:", error);
        return "denied";
      });
  } else {
    return Promise.resolve(Notification.permission);
  }
};
