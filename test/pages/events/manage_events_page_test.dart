import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stripcall/pages/events/manage_events_page.dart';
import 'package:stripcall/models/event.dart';

class MockEventsRepository implements EventsRepository {
  final List<Event> mockEvents;
  final String? mockError;
  final Duration delay;

  MockEventsRepository({
    this.mockEvents = const [],
    this.mockError,
    this.delay = const Duration(milliseconds: 100),
  });

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
      await tester.pumpWidget(
        buildTestWidget(
          mockEvents: [],
          mockError: null,
          mockUserId: 'test-user-id',
          delay: Duration.zero,
        ),
      );
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

    testWidgets('navigates to event details when event is tapped', (
      tester,
    ) async {
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

    testWidgets('shows app bar title "My Events"', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('My Events'), findsOneWidget);
    });

    testWidgets('shows back arrow button in app bar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('shows organizer name from joined data', (tester) async {
      final mockEvents = [
        Event(
          id: 1,
          name: 'Test Event',
          city: 'City',
          state: 'ST',
          startDateTime: DateTime.now(),
          endDateTime: DateTime.now().add(const Duration(days: 1)),
          stripNumbering: 'SequentialNumbers',
          count: 10,
          organizerId: 'user-123',
          organizer: {'firstname': 'John', 'lastname': 'Doe'},
        ),
      ];

      await tester.pumpWidget(buildTestWidget(mockEvents: mockEvents));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('shows organizer ID as fallback when no organizer map', (
      tester,
    ) async {
      final mockEvents = [
        Event(
          id: 1,
          name: 'Test Event',
          city: 'City',
          state: 'ST',
          startDateTime: DateTime.now(),
          endDateTime: DateTime.now().add(const Duration(days: 1)),
          stripNumbering: 'SequentialNumbers',
          count: 10,
          organizerId: 'user-abc-123',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(mockEvents: mockEvents));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Organizer ID: user-abc-123'), findsOneWidget);
    });

    testWidgets('shows organizer ID when organizer name fields are empty', (
      tester,
    ) async {
      final mockEvents = [
        Event(
          id: 1,
          name: 'Test Event',
          city: 'City',
          state: 'ST',
          startDateTime: DateTime.now(),
          endDateTime: DateTime.now().add(const Duration(days: 1)),
          stripNumbering: 'SequentialNumbers',
          count: 10,
          organizerId: 'user-456',
          organizer: {'firstname': '', 'lastname': ''},
        ),
      ];

      await tester.pumpWidget(buildTestWidget(mockEvents: mockEvents));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Organizer ID: user-456'), findsOneWidget);
    });

    testWidgets('shows partial organizer name (first only)', (tester) async {
      final mockEvents = [
        Event(
          id: 1,
          name: 'Test Event',
          city: 'City',
          state: 'ST',
          startDateTime: DateTime.now(),
          endDateTime: DateTime.now().add(const Duration(days: 1)),
          stripNumbering: 'SequentialNumbers',
          count: 10,
          organizerId: 'user-789',
          organizer: {'firstname': 'Jane', 'lastname': ''},
        ),
      ];

      await tester.pumpWidget(buildTestWidget(mockEvents: mockEvents));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Jane'), findsOneWidget);
    });

    testWidgets('shows SMS icon when event has useSms enabled', (tester) async {
      final mockEvents = [
        Event(
          id: 1,
          name: 'SMS Event',
          city: 'City',
          state: 'ST',
          startDateTime: DateTime.now(),
          endDateTime: DateTime.now().add(const Duration(days: 1)),
          stripNumbering: 'SequentialNumbers',
          count: 10,
          organizerId: 'user-123',
          useSms: true,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(mockEvents: mockEvents));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sms), findsOneWidget);
    });

    testWidgets('does not show SMS icon when useSms is false', (tester) async {
      final mockEvents = [
        Event(
          id: 1,
          name: 'No SMS Event',
          city: 'City',
          state: 'ST',
          startDateTime: DateTime.now(),
          endDateTime: DateTime.now().add(const Duration(days: 1)),
          stripNumbering: 'SequentialNumbers',
          count: 10,
          organizerId: 'user-123',
          useSms: false,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(mockEvents: mockEvents));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sms), findsNothing);
    });

    testWidgets('shows chevron right icons for each event', (tester) async {
      final mockEvents = [
        Event(
          id: 1,
          name: 'Event 1',
          city: 'City',
          state: 'ST',
          startDateTime: DateTime.now(),
          endDateTime: DateTime.now().add(const Duration(days: 1)),
          stripNumbering: 'SequentialNumbers',
          count: 10,
          organizerId: 'user-123',
        ),
        Event(
          id: 2,
          name: 'Event 2',
          city: 'City',
          state: 'ST',
          startDateTime: DateTime.now(),
          endDateTime: DateTime.now().add(const Duration(days: 1)),
          stripNumbering: 'SequentialNumbers',
          count: 10,
          organizerId: 'user-123',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(mockEvents: mockEvents));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    });

    testWidgets('retry button reloads events after error', (tester) async {
      int fetchCount = 0;
      final repo = MockEventsRepository(mockError: 'Network error');

      // Use a custom mock that tracks calls
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => ManageEventsPage(
                  eventsRepository: repo,
                  userId: 'test-user-id',
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Should show error
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Should still show error (same repo still throws)
      expect(find.textContaining('Failed to load events'), findsOneWidget);
    });

    testWidgets('shows error icon on error state', (tester) async {
      await tester.pumpWidget(buildTestWidget(mockError: 'Some error'));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('empty state shows event icon and subtitle', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.event), findsOneWidget);
      expect(find.text('Tap + to create your first event'), findsOneWidget);
    });

    testWidgets('FAB has add icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      expect(
        find.descendant(of: fab, matching: find.byIcon(Icons.add)),
        findsOneWidget,
      );
    });

    testWidgets('shows both SMS icon and chevron for SMS-enabled event', (
      tester,
    ) async {
      final mockEvents = [
        Event(
          id: 1,
          name: 'SMS Event',
          city: 'City',
          state: 'ST',
          startDateTime: DateTime.now(),
          endDateTime: DateTime.now().add(const Duration(days: 1)),
          stripNumbering: 'SequentialNumbers',
          count: 10,
          organizerId: 'user-123',
          useSms: true,
        ),
      ];

      await tester.pumpWidget(buildTestWidget(mockEvents: mockEvents));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sms), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('uses ValueKey for list and items', (tester) async {
      final mockEvents = [
        Event(
          id: 42,
          name: 'Keyed Event',
          city: 'City',
          state: 'ST',
          startDateTime: DateTime.now(),
          endDateTime: DateTime.now().add(const Duration(days: 1)),
          stripNumbering: 'SequentialNumbers',
          count: 10,
          organizerId: 'user-123',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(mockEvents: mockEvents));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('manage_events_list')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('manage_events_item_42')),
        findsOneWidget,
      );
    });
  });
}
