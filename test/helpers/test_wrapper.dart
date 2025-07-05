import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stripcall/routes.dart';
import 'test_provider.dart';
import 'mock_supabase.dart';

class TestWrapper extends StatelessWidget {
  final Widget child;
  final List<Map<String, dynamic>> mockEvents;
  final String? mockError;
  final String? mockUserId;
  final Function(String route, {dynamic extra})? onPush;
  final MockSupabaseClient mockClient;

  const TestWrapper({
    super.key,
    required this.child,
    this.mockEvents = const [],
    this.mockError,
    this.mockUserId,
    this.onPush,
    required this.mockClient,
  });

  @override
  Widget build(BuildContext context) {
    return TestProvider(
      mockEvents: mockEvents,
      mockError: mockError,
      mockUserId: mockUserId,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: Routes.manageEvent,
              builder: (context, state) => const Scaffold(),
            ),
            GoRoute(
              path: Routes.login,
              builder: (context, state) => const Scaffold(),
            ),
          ],
          redirect: (context, state) {
            onPush?.call(state.matchedLocation, extra: state.extra);
            return null;
          },
        ),
        builder: (context, child) => child!,
      ),
    );
  }
} 