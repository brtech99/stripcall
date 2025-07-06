// Debug utilities for conditional logging
// Set this to true to enable debug logging, false to disable
const bool kDebugLogging = false;

/// Conditional debug print function
/// Only prints when kDebugLogging is true
void debugLog(String message) {
  if (kDebugLogging) {
    print('DEBUG: $message');
  }
}

/// Conditional debug print function for errors
/// Only prints when kDebugLogging is true
void debugLogError(String message, [Object? error]) {
  if (kDebugLogging) {
    if (error != null) {
      print('DEBUG ERROR: $message - $error');
    } else {
      print('DEBUG ERROR: $message');
    }
  }
} 