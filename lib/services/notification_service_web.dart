// Web platform implementation
import 'dart:js_interop';

// JS interop declarations for web notifications
@JS('initializeNotifications')
external JSPromise? _initializeNotifications();

@JS('getFCMToken')
external JSPromise? _getFCMToken();

bool shouldRequestPermission() => true;

bool isIOS() => false;

bool isAndroid() => false;

String getPlatformName() => 'web';

Future<void> initializeWebNotifications() async {
  try {
    final result = _initializeNotifications();
    if (result != null) {
      await result.toDart;
    }
  } catch (e) {
    // Silently fail - JS function may not exist
  }
}

Future<String?> getFCMTokenFromJS() async {
  try {
    final jsPromise = _getFCMToken();
    if (jsPromise != null) {
      final result = await jsPromise.toDart;
      if (result != null) {
        final tokenStr = (result as JSString).toDart;
        if (tokenStr.isNotEmpty && tokenStr != 'null' && tokenStr != 'undefined') {
          return tokenStr;
        }
      }
    }
  } catch (e) {
    // Silently fail - JS function may not exist
  }
  return null;
}
