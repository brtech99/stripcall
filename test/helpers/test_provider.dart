import 'package:flutter/material.dart';

/// A provider class that provides mock data for testing.
class TestProvider extends InheritedWidget {
  final List<Map<String, dynamic>> mockEvents;
  final String? mockError;
  final String? mockUserId;
  final Function(String, [Object?])? onPush;

  const TestProvider({
    super.key,
    required super.child,
    this.mockEvents = const [],
    this.mockError,
    this.mockUserId,
    this.onPush,
  });

  static TestProvider of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<TestProvider>();
    assert(provider != null, 'No TestProvider found in context');
    return provider!;
  }

  @override
  bool updateShouldNotify(TestProvider oldWidget) {
    return mockEvents != oldWidget.mockEvents ||
        mockError != oldWidget.mockError ||
        mockUserId != oldWidget.mockUserId ||
        onPush != oldWidget.onPush;
  }
} 