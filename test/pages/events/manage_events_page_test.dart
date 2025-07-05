import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stripcall/pages/events/manage_events_page.dart';
import 'package:stripcall/models/event.dart';

class MockEventsRepository implements EventsRepository {
  final List<Event> mockEvents;
  final String? mockError;
  final Duration delay;

  MockEventsRepository({this.mockEvents = const [], this.mockError, this.delay = const Duration(milliseconds: 100)});

  @override
  Future<List<Event>> fetchEvents(String userId) async {
    if (delay.inMilliseconds > 0) {
      await Future.delayed(delay);
    }
    if (mockError != null) {
      throw mockError!;
    }
    return mockEvents;
  }
}

void main() {
  group('ManageEventsPage', () {
    String? lastPushedRoute;
    Object? lastPushedExtra;

    Widget buildTestWidget({
      List<Event> mockEvents = const [],
      String? mockError,
      String? mockUserId,
      Duration delay = const Duration(milliseconds: 100),
    }) {
      return MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => ManageEventsPage(
                eventsRepository: MockEventsRepository(
                  mockEvents: mockEvents,
                  mockError: mockError,
                  delay: delay,
                ),
                userId: 'test-user-id',
              ),
            ),
            GoRoute(
              path: '/manage-event',
              builder: (context, state) => const Scaffold(),
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) => const Scaffold(),
            ),
          ],
          redirect: (context, state) {
            lastPushedRoute = state.matchedLocation;
            lastPushedExtra = state.extra;
            return null;
          },
        ),
      );
    }

    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        mockEvents: [],
        mockError: null,
        mockUserId: 'test-user-id',
        delay: Duration.zero,
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when error occurs', (tester) async {
      const error = 'Test error';
      await tester.pumpWidget(buildTestWidget(mockError: error));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('Failed to load events: $error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows no events message when list is empty', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('No events found'), findsOneWidget);
    });

    testWidgets('shows events list when data is loaded', (tester) async {
      final mockEvents = [
        Event(
          id: 1,
          name: 'Test Event 1',
          city: 'Test City',
          state: 'Test State',
          startDateTime: DateTime.now(),
          endDateTime: DateTime.now().add(const Duration(days: 1)),
          stripNumbering: 'SequentialNumbers',
          count: 10,
          organizerId: 'test-user-id',
        ),
        Event(
          id: 2,
          name: 'Test Event 2',
          city: 'Test City 2',
          state: 'Test State 2',
          startDateTime: DateTime.now(),
          endDateTime: DateTime.now().add(const Duration(days: 1)),
          stripNumbering: 'SequentialNumbers',
          count: 15,
          organizerId: 'test-user-id',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(mockEvents: mockEvents));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Test Event 1'), findsOneWidget);
      expect(find.text('Test Event 2'), findsOneWidget);
    });

    testWidgets('navigates to event details when event is tapped', (tester) async {
      final mockEvent = Event(
        id: 1,
        name: 'Test Event',
        city: 'Test City',
        state: 'Test State',
        startDateTime: DateTime.now(),
        endDateTime: DateTime.now().add(const Duration(days: 1)),
        stripNumbering: 'SequentialNumbers',
        count: 10,
        organizerId: 'test-user-id',
      );

      await tester.pumpWidget(buildTestWidget(mockEvents: [mockEvent]));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Event'));
      await tester.pumpAndSettle();

      expect(lastPushedRoute, '/manage-event');
      expect(lastPushedExtra, mockEvent);
    });

    testWidgets('navigates to create event when FAB is tapped', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(lastPushedRoute, '/manage-event');
      expect(lastPushedExtra, null);
    });
  });
} 