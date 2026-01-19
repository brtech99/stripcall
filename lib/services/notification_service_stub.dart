// Stub implementation - should never be used directly
// This file exists to satisfy the conditional import when neither io nor html is available

bool shouldRequestPermission() => false;

bool isIOS() => false;

bool isAndroid() => false;

String getPlatformName() => 'unknown';

Future<void> initializeWebNotifications() async {}

Future<String?> getFCMTokenFromJS() async => null;
