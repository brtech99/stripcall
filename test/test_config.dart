import 'package:flutter/foundation.dart';

// Enable testing mode for all tests
void enableTestingMode() {
  debugPrint('Enabling testing mode');
  // This will make the TESTING constant true in the app
  assert(() {
    const bool.fromEnvironment('TESTING', defaultValue: true);
    return true;
  }());
} 