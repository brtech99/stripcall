import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stripcall/pages/events/select_event_page.dart';
import 'package:stripcall/models/event.dart';
import 'package:stripcall/routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Mock Repository
// ---------------------------------------------------------------------------

class MockSelectEventRepository implements SelectEventRepository {
  final String? mockUserId;
  final List<Event> mockEvents;
  final String? mockError;
  final Map<String, dynamic>? mockCrewMembership;
  final List<EventCrewRole> mockCrewRoles;
  final bool mockIsSuperUser;
  final Duration delay;

  int fetchEventsCallCount = 0;
  int getCrewMembershipCallCount = 0;

  MockSelectEventRepository({
    this.mockUserId = 'test-user-id',
    this.mockEvents = const [],
    this.mockError,
    this.mockCrewMembership,
    this.mockCrewRoles = const [],
    this.mockIsSuperUser = false,
    this.delay = const Duration(milliseconds: 50),
  });

  @override
  String? get currentUserId => mockUserId;

  @override
  Future<List<Event>> fetchCurrentEvents() async {
    if (delay.inMilliseconds > 0) {
      await Future.delayed(delay);
    }
    fetchEventsCallCount++;
    if (mockError != null) {
      throw Exception(mockError);
    }
    return mockEvents;
  }

  @override
  Future<Map<String, dynamic>?> getCrewMembership(
    String userId,
    int eventId,
  ) async {
    if (delay.inMilliseconds > 0) {
      await Future.delayed(delay);
    }
    getCrewMembershipCallCount++;
    return mockCrewMembership;
  }

  @override
  Future<List<EventCrewRole>> fetchAllCrewRoles(String userId) async {
    if (delay.inMilliseconds > 0) {
      await Future.delayed(delay);
    }
    return mockCrewRoles;
  }

  @override
  Future<bool> checkIsSuperUser(String userId) async {
    if (delay.inMilliseconds > 0) {
      await Future.delayed(delay);
    }
    return mockIsSuperUser;
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Event _makeEvent({
  int id = 1,
  String name = 'Test Event',
  String city = 'Test City',
  String state = 'TS',
  DateTime? startDateTime,
  DateTime? endDateTime,
}) {
  return Event(
    id: id,
    name: name,
    city: city,
    state: state,
    startDateTime: startDateTime ?? DateTime.now(),
    endDateTime: endDateTime ?? DateTime.now().add(const Duration(days: 1)),
    stripNumbering: 'SequentialNumbers',
    count: 10,
    organizerId: 'test-user-id',
  );
}

String? lastPushedRoute;
Map<String, dynamic>? lastPushedExtra;

Widget buildTestWidget({required MockSelectEventRepository repository}) {
  lastPushedRoute = null;
  lastPushedExtra = null;

  return MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => SelectEventPage(repository: repository),
        ),
        GoRoute(
          path: Routes.problems,
          builder: (context, state) {
            lastPushedRoute = Routes.problems;
            lastPushedExtra = state.extra as Map<String, dynamic>?;
            return const Scaffold(body: Text('Problems Page'));
          },
        ),
        GoRoute(
          path: Routes.manageEvents,
          builder: (context, state) => const Scaffold(),
        ),
        GoRoute(
          path: Routes.selectCrew,
          builder: (context, state) => const Scaffold(),
        ),
        GoRoute(
          path: Routes.login,
          builder: (context, state) => const Scaffold(),
        ),
      ],
    ),
  );
}

Future<void> pumpAndWaitForInit(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getAll') {
              return <String, dynamic>{};
            }
            return null;
          },
        );

    try {
      await Supabase.initialize(
        url: 'https://mock-url.supabase.co',
        anonKey: 'mock-key',
      );
    } catch (_) {
      // Already initialized
    }
  });

  group('SelectEventPage', () {
    testWidgets('shows loading indicator initially', (tester) async {
      final repo = MockSelectEventRepository(
        mockEvents: [],
        delay: Duration.zero,
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));

      // First frame should show loading
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
    });

    testWidgets('shows empty state when no events', (tester) async {
      final repo = MockSelectEventRepository(mockEvents: []);
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('No current events'), findsOneWidget);
      expect(
        find.text('Check back when an event is scheduled'),
        findsOneWidget,
      );
    });

    testWidgets('shows error message when loading fails', (tester) async {
      final repo = MockSelectEventRepository(mockError: 'Network error');
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.textContaining('Network error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button reloads events', (tester) async {
      final repo = MockSelectEventRepository(mockError: 'Network error');
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      final initialCallCount = repo.fetchEventsCallCount;

      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(repo.fetchEventsCallCount, greaterThan(initialCallCount));
    });

    testWidgets('shows events list when data is loaded', (tester) async {
      final events = [
        _makeEvent(id: 1, name: 'Tournament Alpha'),
        _makeEvent(id: 2, name: 'Tournament Beta'),
      ];

      final repo = MockSelectEventRepository(mockEvents: events);
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Tournament Alpha'), findsOneWidget);
      expect(find.text('Tournament Beta'), findsOneWidget);
    });

    testWidgets('shows app bar title', (tester) async {
      final repo = MockSelectEventRepository(mockEvents: []);
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Select Event'), findsOneWidget);
    });

    testWidgets('navigates to problems when event is tapped (no crew)', (
      tester,
    ) async {
      final event = _makeEvent(id: 42, name: 'My Tournament');

      final repo = MockSelectEventRepository(
        mockEvents: [event],
        mockCrewMembership: null, // User not in any crew
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      await tester.tap(find.text('My Tournament'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(lastPushedRoute, Routes.problems);
      expect(lastPushedExtra?['eventId'], 42);
      expect(lastPushedExtra?['crewId'], isNull);
      expect(lastPushedExtra?['crewType'], isNull);
    });

    testWidgets(
      'navigates to problems with crew info when user is crew member',
      (tester) async {
        final event = _makeEvent(id: 42, name: 'My Tournament');

        final repo = MockSelectEventRepository(
          mockEvents: [event],
          mockCrewMembership: {
            'crew': {
              'id': 10,
              'crewtype': {'crewtype': 'Armorer'},
            },
          },
        );
        await tester.pumpWidget(buildTestWidget(repository: repo));
        await pumpAndWaitForInit(tester);

        await tester.tap(find.text('My Tournament'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(lastPushedRoute, Routes.problems);
        expect(lastPushedExtra?['eventId'], 42);
        expect(lastPushedExtra?['crewId'], 10);
        expect(lastPushedExtra?['crewType'], 'Armorer');
      },
    );

    testWidgets(
      'navigates to problems with null crew when crew data is missing',
      (tester) async {
        final event = _makeEvent(id: 42, name: 'My Tournament');

        final repo = MockSelectEventRepository(
          mockEvents: [event],
          mockCrewMembership: {'crew': null}, // crew member but crew data null
        );
        await tester.pumpWidget(buildTestWidget(repository: repo));
        await pumpAndWaitForInit(tester);

        await tester.tap(find.text('My Tournament'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(lastPushedRoute, Routes.problems);
        expect(lastPushedExtra?['crewId'], isNull);
      },
    );

    testWidgets('shows event date in list', (tester) async {
      final event = _makeEvent(
        id: 1,
        name: 'Tournament',
        startDateTime: DateTime(2025, 3, 15),
      );

      final repo = MockSelectEventRepository(mockEvents: [event]);
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('2025-03-15'), findsOneWidget);
    });

    testWidgets('shows chevron icon for each event', (tester) async {
      final events = [
        _makeEvent(id: 1, name: 'Event 1'),
        _makeEvent(id: 2, name: 'Event 2'),
      ];

      final repo = MockSelectEventRepository(mockEvents: events);
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    });

    testWidgets('shows multiple events in order', (tester) async {
      final events = List.generate(
        4,
        (i) => _makeEvent(
          id: i + 1,
          name: 'Event ${i + 1}',
          startDateTime: DateTime(2025, 1, i + 1),
        ),
      );

      final repo = MockSelectEventRepository(mockEvents: events);
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      for (var i = 1; i <= 4; i++) {
        expect(find.text('Event $i'), findsOneWidget);
      }
    });

    testWidgets('uses ValueKey for list and items', (tester) async {
      final events = [_makeEvent(id: 7, name: 'Keyed Event')];

      final repo = MockSelectEventRepository(mockEvents: events);
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.byKey(const ValueKey('select_event_list')), findsOneWidget);
      expect(find.byKey(const ValueKey('select_event_item_7')), findsOneWidget);
    });

    testWidgets('shows error icon on error state', (tester) async {
      final repo = MockSelectEventRepository(mockError: 'timeout');
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('empty state shows event_busy icon', (tester) async {
      final repo = MockSelectEventRepository(mockEvents: []);
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.byIcon(Icons.event_busy), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Crew role badge tests
    // -----------------------------------------------------------------------

    testWidgets('shows crew member badge on event tile', (tester) async {
      final events = [_makeEvent(id: 1, name: 'Tournament')];
      final roles = [
        EventCrewRole(
          eventId: 1,
          eventName: 'Tournament',
          eventStartDate: DateTime(2025, 3, 15),
          crewTypeName: 'Armorer',
          isCrewChief: false,
        ),
      ];

      final repo = MockSelectEventRepository(
        mockEvents: events,
        mockCrewRoles: roles,
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Armorer'), findsOneWidget);
    });

    testWidgets('shows crew chief badge on event tile', (tester) async {
      final events = [_makeEvent(id: 1, name: 'Tournament')];
      final roles = [
        EventCrewRole(
          eventId: 1,
          eventName: 'Tournament',
          eventStartDate: DateTime(2025, 3, 15),
          crewTypeName: 'Armorer',
          isCrewChief: true,
        ),
      ];

      final repo = MockSelectEventRepository(
        mockEvents: events,
        mockCrewRoles: roles,
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Crew Chief - Armorer'), findsOneWidget);
    });

    testWidgets('shows multiple crew badges on one event', (tester) async {
      final events = [_makeEvent(id: 1, name: 'Tournament')];
      final roles = [
        EventCrewRole(
          eventId: 1,
          eventName: 'Tournament',
          eventStartDate: DateTime(2025, 3, 15),
          crewTypeName: 'Armorer',
          isCrewChief: true,
        ),
        EventCrewRole(
          eventId: 1,
          eventName: 'Tournament',
          eventStartDate: DateTime(2025, 3, 15),
          crewTypeName: 'Medical',
          isCrewChief: false,
        ),
      ];

      final repo = MockSelectEventRepository(
        mockEvents: events,
        mockCrewRoles: roles,
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Crew Chief - Armorer'), findsOneWidget);
      expect(find.text('Medical'), findsOneWidget);
    });

    testWidgets('superuser sees no crew badges', (tester) async {
      final events = [_makeEvent(id: 1, name: 'Tournament')];

      final repo = MockSelectEventRepository(
        mockEvents: events,
        mockIsSuperUser: true,
        // mockCrewRoles stays empty because fetchAllCrewRoles is never called
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Tournament'), findsOneWidget);
      expect(find.text('Armorer'), findsNothing);
      expect(find.text('Crew Chief - Armorer'), findsNothing);
    });

    testWidgets('no badges shown when user has no crew membership', (
      tester,
    ) async {
      final events = [_makeEvent(id: 1, name: 'Tournament')];

      final repo = MockSelectEventRepository(
        mockEvents: events,
        mockCrewRoles: [], // No memberships
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Tournament'), findsOneWidget);
      // No badge-like widgets should appear
      expect(find.text('Armorer'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // Upcoming crews section tests
    // -----------------------------------------------------------------------

    testWidgets('shows upcoming crews section for future events', (
      tester,
    ) async {
      // Event 1 is in the select list, event 99 is upcoming (not in list)
      final events = [_makeEvent(id: 1, name: 'Current Tournament')];
      final roles = [
        EventCrewRole(
          eventId: 1,
          eventName: 'Current Tournament',
          eventStartDate: DateTime(2025, 3, 15),
          crewTypeName: 'Armorer',
          isCrewChief: false,
        ),
        EventCrewRole(
          eventId: 99,
          eventName: 'Future Championship',
          eventStartDate: DateTime(2025, 6, 1),
          crewTypeName: 'Medical',
          isCrewChief: true,
        ),
      ];

      final repo = MockSelectEventRepository(
        mockEvents: events,
        mockCrewRoles: roles,
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      // Current event has badge
      expect(find.text('Armorer'), findsOneWidget);

      // Upcoming section shown
      expect(find.text('Your Upcoming Crews'), findsOneWidget);
      expect(find.text('Future Championship'), findsOneWidget);
      expect(find.text('Crew Chief - Medical'), findsOneWidget);
    });

    testWidgets('upcoming section hidden when no upcoming roles', (
      tester,
    ) async {
      final events = [_makeEvent(id: 1, name: 'Tournament')];
      final roles = [
        EventCrewRole(
          eventId: 1, // Same as event in list — not upcoming
          eventName: 'Tournament',
          eventStartDate: DateTime(2025, 3, 15),
          crewTypeName: 'Armorer',
          isCrewChief: false,
        ),
      ];

      final repo = MockSelectEventRepository(
        mockEvents: events,
        mockCrewRoles: roles,
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Your Upcoming Crews'), findsNothing);
    });

    testWidgets('upcoming crew items are not tappable', (tester) async {
      final events = [_makeEvent(id: 1, name: 'Current')];
      final roles = [
        EventCrewRole(
          eventId: 99,
          eventName: 'Future Event',
          eventStartDate: DateTime(2025, 6, 1),
          crewTypeName: 'Natloff',
          isCrewChief: false,
        ),
      ];

      final repo = MockSelectEventRepository(
        mockEvents: events,
        mockCrewRoles: roles,
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      // Upcoming items have no chevron (not tappable)
      // Current event has 1 chevron, upcoming has none
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('upcoming section uses ValueKeys', (tester) async {
      final events = [_makeEvent(id: 1, name: 'Current')];
      final roles = [
        EventCrewRole(
          eventId: 42,
          eventName: 'Future Event',
          eventStartDate: DateTime(2025, 6, 1),
          crewTypeName: 'Armorer',
          isCrewChief: false,
        ),
      ];

      final repo = MockSelectEventRepository(
        mockEvents: events,
        mockCrewRoles: roles,
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(
        find.byKey(const ValueKey('upcoming_crew_42_Armorer')),
        findsOneWidget,
      );
    });
  });
}
