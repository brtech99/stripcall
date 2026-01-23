// Mobile platform (iOS/Android) implementation
import 'dart:io' show Platform;

bool shouldRequestPermission() => true; // Both iOS and Android 13+ need permission

bool isIOS() => Platform.isIOS;

bool isAndroid() => Platform.isAndroid;

String getPlatformName() => Platform.isIOS ? 'ios' : 'android';

Future<void> initializeWebNotifications() async {
  // No-op on mobile
}

Future<String?> getFCMTokenFromJS() async {
  // Not applicable on mobile
  return null;
}
