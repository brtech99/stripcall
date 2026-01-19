// Stub implementation for non-web platforms
// These functions are no-ops on mobile

String getNotificationPermission() => 'denied';

void showTestNotification(String title, String body, String icon) {
  // No-op on mobile
}

void requestNotificationPermission() {
  // No-op on mobile
}
