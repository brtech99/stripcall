// Debug utilities for conditional logging
// Set this to true to enable debug logging, false to disable
const bool kDebugLogging = true;

/// Conditional debug print function
/// Only prints when kDebugLogging is true
void debugLog(String message) {
  if (kDebugLogging) {
    // ignore: avoid_print
    print('DEBUG: $message');
  }
}

/// Conditional debug print function for errors
/// Only prints when kDebugLogging is true
void debugLogError(String message, [Object? error]) {
  if (kDebugLogging) {
    if (error != null) {
      // ignore: avoid_print
      print('DEBUG ERROR: $message - $error');
    } else {
      // ignore: avoid_print
      print('DEBUG ERROR: $message');
    }
  }
} 