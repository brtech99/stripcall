// Web implementation for browser Notification API
import 'dart:js_interop';

// JS interop for browser Notification API
@JS('Notification')
extension type _JSNotification._(JSObject _) implements JSObject {
  external _JSNotification(String title, [_JSNotificationOptions? options]);
  external static String get permission;
  external static JSPromise<JSString> requestPermission();
}

@JS()
@anonymous
extension type _JSNotificationOptions._(JSObject _) implements JSObject {
  external factory _JSNotificationOptions({String? body, String? icon});
}

String getNotificationPermission() {
  try {
    return _JSNotification.permission;
  } catch (e) {
    return 'denied';
  }
}

void showTestNotification(String title, String body, String icon) {
  try {
    _JSNotification(
      title,
      _JSNotificationOptions(body: body, icon: icon),
    );
  } catch (e) {
    // Silently fail
  }
}

void requestNotificationPermission() {
  try {
    _JSNotification.requestPermission();
  } catch (e) {
    // Silently fail
  }
}
