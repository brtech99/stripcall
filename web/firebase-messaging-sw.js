// Firebase messaging service worker
importScripts(
  "https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js",
);
importScripts(
  "https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js",
);

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

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log("Received background message:", payload);

  const notificationTitle = payload.notification?.title || "New Message";
  const notificationOptions = {
    body: payload.notification?.body || "",
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
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

  return self.registration.showNotification(
    notificationTitle,
    notificationOptions,
  );
});

// Handle notification clicks
self.addEventListener("notificationclick", (event) => {
  console.log("Notification clicked:", event);

  event.notification.close();

  if (event.action === "open") {
    // Open the app
    event.waitUntil(clients.openWindow("/"));
  }
});
