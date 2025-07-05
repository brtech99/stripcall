import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TestConfig {
  static Future<void> setup() async {
    // Mock shared preferences
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getAll') {
              return <String, dynamic>{}; // Return empty map for testing
            }
            return null;
          },
        );

    // Initialize Supabase
    await Supabase.initialize(
      url: 'https://mock-url.supabase.co',
      anonKey: 'mock-key',
      debug: false,
      storageOptions: const StorageClientOptions(),
      httpClient: null,
    );
  }
} 