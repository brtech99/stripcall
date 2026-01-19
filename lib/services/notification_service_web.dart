// Web platform implementation
import 'dart:js_interop';

// JS interop declarations for web notifications
@JS('initializeNotifications')
external JSAny? _initializeNotifications();

@JS('getFCMToken')
external JSAny? _getFCMToken();

bool shouldRequestPermission() => true;

bool isIOS() => false;

bool isAndroid() => false;

String getPlatformName() => 'web';

Future<void> initializeWebNotifications() async {
  try {
    final result = _initializeNotifications();
    if (result != null) {
      // Wait for the promise to resolve
      await Future.delayed(const Duration(milliseconds: 500));
    }
  } catch (e) {
    // Silently fail - JS function may not exist
  }
}

Future<String?> getFCMTokenFromJS() async {
  try {
    final jsToken = _getFCMToken();
    if (jsToken != null) {
      // Try to convert to string
      final tokenStr = jsToken.toString();
      if (tokenStr.isNotEmpty && tokenStr != 'null' && tokenStr != 'undefined') {
        return tokenStr;
      }
    }

    // Wait and retry
    await Future.delayed(const Duration(seconds: 2));

    final retryToken = _getFCMToken();
    if (retryToken != null) {
      final retryStr = retryToken.toString();
      if (retryStr.isNotEmpty && retryStr != 'null' && retryStr != 'undefined') {
        return retryStr;
      }
    }
  } catch (e) {
    // Silently fail - JS function may not exist
  }
  return null;
}
