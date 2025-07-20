// Firebase configuration for web
const firebaseConfig = {
  apiKey: "AIzaSyDjMXfc5G1dWJ550vrFPpOttgsZDkZV1o4",
  authDomain: "stripcalls-458912.firebaseapp.com",
  projectId: "stripcalls-458912",
  storageBucket: "stripcalls-458912.firebasestorage.app",
  messagingSenderId: "955423518908",
  appId: "1:955423518908:web:f5b75410cb94b99a1660b9",
};

// VAPID key for push notifications - this should be the public key from Firebase console
const vapidKey = "BEl62iUYgUivxIkv69yViEuiBIa1lQJHRlVQlBXhsS8JfSxOBuVRjAifBRUONyHNUUxKQllAtojljGUkpl4vTYBg";

// Convert VAPID key to Uint8Array
function urlBase64ToUint8Array(base64String) {
  try {
    // Remove any whitespace and ensure proper padding
    const cleanBase64 = base64String.replace(/\s/g, '');
    const padding = '='.repeat((4 - cleanBase64.length % 4) % 4);
    const base64 = (cleanBase64 + padding)
      .replace(/-/g, '+')
      .replace(/_/g, '/');

    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  } catch (error) {
    console.error('Error converting VAPID key:', error);
    // Return a fallback or throw error
    throw new Error('Invalid VAPID key format');
  }
}

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

// Initialize Firebase Cloud Messaging
const messaging = firebase.messaging();

// Register service worker
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/firebase-messaging-sw.js')
    .then(function(registration) {
      console.log('Service Worker registered with scope:', registration.scope);
      // Wait for service worker to be ready before requesting token
      return navigator.serviceWorker.ready;
    })
    .then(function(registration) {
      console.log('Service Worker is ready');
      // Now request permission and token
      return requestPermissionAndToken();
    })
    .catch(function(err) {
      console.log('Service Worker registration failed:', err);
    });
} else {
  console.log('Service Worker not supported');
}

// Function to request permission and get token
function requestPermissionAndToken() {
  return Notification.requestPermission()
    .then(function(permission) {
      console.log('Notification permission:', permission);
      if (permission === 'granted') {
        console.log('Requesting FCM token...');
        return messaging.getToken();
      } else {
        console.log('❌ Notification permission denied');
        return null;
      }
    })
    .then(function(currentToken) {
      if (currentToken) {
        console.log('✅ FCM token obtained successfully!');
        console.log('FCM token:', currentToken);
        // Store token for later use
        window.fcmToken = currentToken;
      } else {
        console.log('❌ No registration token available.');
      }
    })
    .catch(function(err) {
      console.log('❌ An error occurred while retrieving token. ', err);
    });
}

// Permission and token request is now handled by requestPermissionAndToken()
// after the service worker is ready

// Handle foreground messages
messaging.onMessage((payload) => {
  console.log('Message received in foreground. ', payload);
  // Show notification manually
  showNotification(payload);
});

function showNotification(payload) {
  const notificationTitle = payload.notification?.title || 'New Message';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: 'stripcall-notification',
    requireInteraction: true,
    actions: [
      {
        action: 'open',
        title: 'Open'
      },
      {
        action: 'close',
        title: 'Close'
      }
    ]
  };

  if ('serviceWorker' in navigator && 'Notification' in window) {
    navigator.serviceWorker.ready.then(function(registration) {
      registration.showNotification(notificationTitle, notificationOptions);
    });
  }
}

// Test function to show a local notification
function testLocalNotification() {
  console.log('=== JavaScript: Testing local notification ===');
  console.log('Service Worker available:', 'serviceWorker' in navigator);
  console.log('Notification API available:', 'Notification' in window);
  console.log('Notification permission:', Notification.permission);
  
  // First, try a simple direct notification without service worker
  if ('Notification' in window && Notification.permission === 'granted') {
    console.log('Trying direct notification...');
    try {
      const notification = new Notification('Direct Test', {
        body: 'This is a direct test notification',
        icon: '/icons/Icon-192.png',
        requireInteraction: true
      });
      console.log('✅ Direct notification created successfully!');
      
      notification.onclick = function() {
        console.log('Direct notification clicked');
        window.focus();
      };
    } catch (error) {
      console.error('❌ Error creating direct notification:', error);
    }
  }
  
  // Then try the service worker notification
  if ('serviceWorker' in navigator && 'Notification' in window) {
    console.log('Getting service worker registration...');
    navigator.serviceWorker.ready.then(function(registration) {
      console.log('Service worker ready, showing notification...');
      registration.showNotification('Service Worker Test', {
        body: 'This is a service worker test notification!',
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        tag: 'test-notification',
        requireInteraction: true,
        actions: [
          {
            action: 'open',
            title: 'Open'
          },
          {
            action: 'close',
            title: 'Close'
          }
        ]
      }).then(function() {
        console.log('✅ Service worker notification sent successfully!');
      }).catch(function(error) {
        console.error('❌ Error showing service worker notification:', error);
      });
    }).catch(function(error) {
      console.error('❌ Error getting service worker:', error);
    });
  } else {
    console.error('❌ Service Worker or Notification API not available');
  }
}

// Function to expose FCM token to Dart
window.getFCMToken = function() {
  return window.fcmToken;
};

// Make test function available globally
window.testLocalNotification = testLocalNotification; 