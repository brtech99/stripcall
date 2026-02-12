import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stripcall/pages/events/manage_event_page.dart';
import 'package:stripcall/models/event.dart';
import 'package:stripcall/models/crew.dart';
import 'package:stripcall/models/crew_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Mock Repository
// ---------------------------------------------------------------------------

class MockManageEventRepository implements ManageEventRepository {
  final String? mockUserId;
  final bool mockIsSuperUser;
  final List<Crew> mockCrews;
  final List<CrewType> mockCrewTypes;
  final String? mockLoadError;
  final String? mockSaveError;
  final Duration delay;

  int saveEventCallCount = 0;
  Map<String, dynamic>? lastSavedData;
  int? lastSavedEventId;

  MockManageEventRepository({
    this.mockUserId = 'test-user-id',
    this.mockIsSuperUser = false,
    this.mockCrews = const [],
    this.mockCrewTypes = const [],
    this.mockLoadError,
    this.mockSaveError,
    this.delay = const Duration(milliseconds: 50),
  });

  Future<void> _maybeDelay() async {
    if (delay.inMilliseconds > 0) {
      await Future.delayed(delay);
    }
  }

  @override
  String? get currentUserId => mockUserId;

  @override
  Future<bool> checkSuperUser() async {
    await _maybeDelay();
    return mockIsSuperUser;
  }

  @override
  Future<List<Crew>> loadCrews(int eventId) async {
    await _maybeDelay();
    if (mockLoadError != null) throw Exception(mockLoadError);
    return mockCrews;
  }

  @override
  Future<List<CrewType>> loadCrewTypes() async {
    await _maybeDelay();
    return mockCrewTypes;
  }

  @override
  Future<void> saveEvent(Map<String, dynamic> data, {int? eventId}) async {
    await _maybeDelay();
    saveEventCallCount++;
    lastSavedData = data;
    lastSavedEventId = eventId;
    if (mockSaveError != null) throw Exception(mockSaveError);
  }

  @override
  Future<List<Map<String, dynamic>>> checkSmsOverlap(
    DateTime start,
    DateTime end,
    int? excludeEventId,
  ) async {
    return [];
  }

  @override
  Future<void> addCrew(int eventId, String crewChiefId, int crewTypeId) async {}

  @override
  Future<void> updateCrewChief(int crewId, String crewChiefId) async {}

  @override
  Future<void> deleteCrew(int crewId) async {}

  @override
  Future<int> getCrewProblemCount(int crewId) async => 0;

  @override
  Future<int> getCrewMessageCount(int crewId) async => 0;

  @override
  Future<int> getCrewCrewMessageCount(int crewId) async => 0;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Event _makeEvent({
  int id = 1,
  String name = 'Test Event',
  String city = 'Test City',
  String state = 'TS',
  DateTime? startDateTime,
  DateTime? endDateTime,
  String stripNumbering = 'SequentialNumbers',
  int count = 10,
}) {
  return Event(
    id: id,
    name: name,
    city: city,
    state: state,
    startDateTime: startDateTime ?? DateTime(2025, 3, 1),
    endDateTime: endDateTime ?? DateTime(2025, 3, 5),
    stripNumbering: stripNumbering,
    count: count,
    organizerId: 'test-user-id',
  );
}

Crew _makeCrew({
  int id = 1,
  int eventId = 1,
  String crewChiefId = 'chief-1',
  int crewTypeId = 1,
  Map<String, dynamic>? crewChief,
}) {
  return Crew(
    id: id,
    eventId: eventId,
    crewChiefId: crewChiefId,
    crewTypeId: crewTypeId,
    crewChief: crewChief ?? {'firstname': 'John', 'lastname': 'Doe'},
  );
}

Widget buildTestWidget({
  required MockManageEventRepository repository,
  Event? event,
}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              ManageEventPage(event: event, repository: repository),
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
    } catch (_) {}
  });

  group('ManageEventPage - Create mode', () {
    testWidgets('shows "Create Event" title when no event provided', (
      tester,
    ) async {
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Create Event'), findsWidgets); // title + button
    });

    testWidgets('shows empty form fields for new event', (tester) async {
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      // Form fields should be present
      expect(find.text('Event Name'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('State'), findsOneWidget);
    });

    testWidgets('shows date fields as "Not set" for new event', (tester) async {
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.textContaining('Start Date: Not set'), findsOneWidget);
      expect(find.textContaining('End Date: Not set'), findsOneWidget);
    });

    testWidgets('does not show crews section for new event', (tester) async {
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Crews'), findsNothing);
    });

    testWidgets('shows strip numbering dropdown', (tester) async {
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Strip Numbering'), findsOneWidget);
      expect(find.text('Sequential Numbers'), findsOneWidget);
    });

    testWidgets('shows validation error for empty event name', (tester) async {
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      // Scroll to make save button visible (form is longer than viewport)
      final saveButton = find.byKey(const ValueKey('manage_event_save_button'));
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter an event name'), findsOneWidget);
      expect(repo.saveEventCallCount, 0);
    });

    testWidgets('shows validation error for missing dates', (tester) async {
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      // Enter a name first
      await tester.enterText(
        find.byKey(const ValueKey('manage_event_name_field')),
        'My Event',
      );
      await tester.pumpAndSettle();

      // Scroll to make save button visible
      final saveButton = find.byKey(const ValueKey('manage_event_save_button'));
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Please set both start and end dates'), findsOneWidget);
      expect(repo.saveEventCallCount, 0);
    });
  });

  group('ManageEventPage - Edit mode', () {
    testWidgets('shows "Edit Event" title when event provided', (tester) async {
      final event = _makeEvent(name: 'Tournament');
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      expect(find.text('Edit Event'), findsOneWidget);
    });

    testWidgets('populates form fields from event', (tester) async {
      final event = _makeEvent(
        name: 'Tournament Alpha',
        city: 'Denver',
        state: 'CO',
        count: 24,
      );
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      // Fields should contain event data
      final nameField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('manage_event_name_field')),
          matching: find.byType(TextField),
        ),
      );
      expect(nameField.controller?.text, 'Tournament Alpha');
    });

    testWidgets('shows crews section for existing event', (tester) async {
      final event = _makeEvent();
      final crews = [
        _makeCrew(id: 1, crewTypeId: 1),
        _makeCrew(id: 2, crewTypeId: 2),
      ];
      final crewTypes = [
        const CrewType(id: 1, crewType: 'Armorer'),
        const CrewType(id: 2, crewType: 'Medical'),
        const CrewType(id: 3, crewType: 'Natloff'),
      ];

      final repo = MockManageEventRepository(
        mockCrews: crews,
        mockCrewTypes: crewTypes,
      );
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      expect(find.text('Crews'), findsOneWidget);
      expect(find.text('Armorer'), findsOneWidget);
      expect(find.text('Medical'), findsOneWidget);
    });

    testWidgets('shows crew chief names', (tester) async {
      final event = _makeEvent();
      final crews = [
        _makeCrew(
          id: 1,
          crewTypeId: 1,
          crewChief: {'firstname': 'Alice', 'lastname': 'Smith'},
        ),
      ];
      final crewTypes = [const CrewType(id: 1, crewType: 'Armorer')];

      final repo = MockManageEventRepository(
        mockCrews: crews,
        mockCrewTypes: crewTypes,
      );
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      expect(find.textContaining('Alice Smith'), findsOneWidget);
    });

    testWidgets('shows "No crews found" when empty', (tester) async {
      final event = _makeEvent();
      final repo = MockManageEventRepository(
        mockCrews: [],
        mockCrewTypes: [const CrewType(id: 1, crewType: 'Armorer')],
      );
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      expect(find.text('No crews found'), findsOneWidget);
    });

    testWidgets('shows add crew button when available types exist', (
      tester,
    ) async {
      final event = _makeEvent();
      final repo = MockManageEventRepository(
        mockCrews: [],
        mockCrewTypes: [const CrewType(id: 1, crewType: 'Armorer')],
      );
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      expect(
        find.byKey(const ValueKey('manage_event_add_crew_button')),
        findsOneWidget,
      );
    });

    testWidgets('hides add crew button when all types used', (tester) async {
      final event = _makeEvent();
      final repo = MockManageEventRepository(
        mockCrews: [_makeCrew(id: 1, crewTypeId: 1)],
        mockCrewTypes: [const CrewType(id: 1, crewType: 'Armorer')],
      );
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      expect(
        find.byKey(const ValueKey('manage_event_add_crew_button')),
        findsNothing,
      );
    });

    testWidgets('shows Save button for existing event', (tester) async {
      final event = _makeEvent();
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows edit and delete buttons for each crew', (tester) async {
      final event = _makeEvent();
      final crews = [
        _makeCrew(id: 1, crewTypeId: 1),
        _makeCrew(id: 2, crewTypeId: 2),
      ];
      final crewTypes = [
        const CrewType(id: 1, crewType: 'Armorer'),
        const CrewType(id: 2, crewType: 'Medical'),
      ];

      final repo = MockManageEventRepository(
        mockCrews: crews,
        mockCrewTypes: crewTypes,
      );
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      expect(find.byIcon(Icons.edit), findsNWidgets(2));
      expect(find.byIcon(Icons.delete), findsNWidgets(2));
    });

    testWidgets('shows error when loading fails', (tester) async {
      final event = _makeEvent();
      final repo = MockManageEventRepository(
        mockLoadError: 'DB connection failed',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      expect(
        find.textContaining('Failed to load event details'),
        findsOneWidget,
      );
    });

    testWidgets('shows date values for existing event', (tester) async {
      final event = _makeEvent(
        startDateTime: DateTime(2025, 3, 1),
        endDateTime: DateTime(2025, 3, 5),
      );
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      expect(find.textContaining('Start Date: 2025-03-01'), findsOneWidget);
      expect(find.textContaining('End Date: 2025-03-05'), findsOneWidget);
    });

    testWidgets('shows Pick buttons for dates', (tester) async {
      final event = _makeEvent();
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      expect(find.text('Pick'), findsNWidgets(2));
    });

    testWidgets('shows validation error when end date is before start date', (
      tester,
    ) async {
      // Create event with end before start to test that validation
      final event = _makeEvent(
        startDateTime: DateTime(2025, 3, 5),
        endDateTime: DateTime(2025, 3, 1), // end before start
      );
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      final saveButton = find.byKey(const ValueKey('manage_event_save_button'));
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('End date must be after start date'), findsOneWidget);
      expect(repo.saveEventCallCount, 0);
    });

    testWidgets('successful save calls repository with event data', (
      tester,
    ) async {
      final event = _makeEvent(
        name: 'Tournament Alpha',
        city: 'Denver',
        state: 'CO',
        startDateTime: DateTime(2025, 3, 1),
        endDateTime: DateTime(2025, 3, 5),
      );
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      final saveButton = find.byKey(const ValueKey('manage_event_save_button'));
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(repo.saveEventCallCount, 1);
      expect(repo.lastSavedData?['name'], 'Tournament Alpha');
      expect(repo.lastSavedData?['city'], 'Denver');
      expect(repo.lastSavedData?['state'], 'CO');
      expect(repo.lastSavedEventId, event.id);
    });

    testWidgets('shows save error in state when save fails', (tester) async {
      final event = _makeEvent(
        startDateTime: DateTime(2025, 3, 1),
        endDateTime: DateTime(2025, 3, 5),
      );
      final repo = MockManageEventRepository(mockSaveError: 'DB write failed');
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      final saveButton = find.byKey(const ValueKey('manage_event_save_button'));
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to save event'), findsOneWidget);
    });

    testWidgets('shows SMS toggle for super user on existing event', (
      tester,
    ) async {
      final event = _makeEvent();
      final repo = MockManageEventRepository(mockIsSuperUser: true);
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      final smsSwitch = find.byKey(
        const ValueKey('manage_event_use_sms_switch'),
      );
      await tester.ensureVisible(smsSwitch);
      await tester.pumpAndSettle();

      expect(smsSwitch, findsOneWidget);
    });

    testWidgets('SMS toggle not shown for new event (create mode)', (
      tester,
    ) async {
      final repo = MockManageEventRepository(mockIsSuperUser: true);
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(
        find.byKey(const ValueKey('manage_event_use_sms_switch')),
        findsNothing,
      );
    });

    testWidgets('strip numbering dropdown can be changed', (tester) async {
      final event = _makeEvent(stripNumbering: 'SequentialNumbers');
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      // Find the dropdown and tap to open
      final dropdown = find.byKey(
        const ValueKey('manage_event_strip_numbering_dropdown'),
      );
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Select "Pods"
      await tester.tap(find.text('Pods').last);
      await tester.pumpAndSettle();

      // Label should change from "Number of Strips" to "Number of Pods"
      expect(find.text('Number of Pods'), findsOneWidget);
    });

    testWidgets('crew chief ID fallback when name is empty', (tester) async {
      final event = _makeEvent();
      final crews = [
        _makeCrew(
          id: 1,
          crewTypeId: 1,
          crewChiefId: 'chief-abc',
          crewChief: {'firstname': '', 'lastname': ''},
        ),
      ];
      final crewTypes = [const CrewType(id: 1, crewType: 'Armorer')];

      final repo = MockManageEventRepository(
        mockCrews: crews,
        mockCrewTypes: crewTypes,
      );
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      expect(find.textContaining('Chief ID: chief-abc'), findsOneWidget);
    });

    testWidgets('crew chief ID fallback when no crewChief map', (tester) async {
      final event = _makeEvent();
      final crews = [
        Crew(
          id: 1,
          eventId: 1,
          crewChiefId: 'chief-xyz',
          crewTypeId: 1,
          crewChief: null,
        ),
      ];
      final crewTypes = [const CrewType(id: 1, crewType: 'Armorer')];

      final repo = MockManageEventRepository(
        mockCrews: crews,
        mockCrewTypes: crewTypes,
      );
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      expect(find.textContaining('Chief ID: chief-xyz'), findsOneWidget);
    });

    testWidgets('count field updates strip count', (tester) async {
      final event = _makeEvent(count: 10);
      final repo = MockManageEventRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      final countField = find.byKey(const ValueKey('manage_event_count_field'));
      await tester.ensureVisible(countField);
      await tester.pumpAndSettle();

      // Clear and enter new value
      await tester.enterText(countField, '25');
      await tester.pumpAndSettle();

      // Save and verify the count was passed
      final saveButton = find.byKey(const ValueKey('manage_event_save_button'));
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(repo.lastSavedData?['count'], 25);
    });

    testWidgets(
      'notify superusers toggle shown for superuser on existing event',
      (tester) async {
        final event = _makeEvent();
        final repo = MockManageEventRepository(mockIsSuperUser: true);
        await tester.pumpWidget(
          buildTestWidget(repository: repo, event: event),
        );
        await pumpAndWaitForInit(tester);

        final toggle = find.byKey(
          const ValueKey('manage_event_notify_superusers_switch'),
        );
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();

        expect(toggle, findsOneWidget);
      },
    );

    testWidgets('notify superusers toggle not shown for new event', (
      tester,
    ) async {
      final repo = MockManageEventRepository(mockIsSuperUser: true);
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(
        find.byKey(const ValueKey('manage_event_notify_superusers_switch')),
        findsNothing,
      );
    });

    testWidgets('notify superusers toggle disabled for non-superuser', (
      tester,
    ) async {
      final event = _makeEvent();
      final repo = MockManageEventRepository(mockIsSuperUser: false);
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      final toggle = find.byKey(
        const ValueKey('manage_event_notify_superusers_switch'),
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<SwitchListTile>(toggle);
      expect(switchWidget.onChanged, isNull);
    });

    testWidgets('notify superusers defaults to true', (tester) async {
      final event = _makeEvent();
      final repo = MockManageEventRepository(mockIsSuperUser: true);
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      final toggle = find.byKey(
        const ValueKey('manage_event_notify_superusers_switch'),
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<SwitchListTile>(toggle);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('notify superusers saved when superuser saves event', (
      tester,
    ) async {
      final event = _makeEvent(
        startDateTime: DateTime(2025, 3, 1),
        endDateTime: DateTime(2025, 3, 5),
      );
      final repo = MockManageEventRepository(mockIsSuperUser: true);
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      final saveButton = find.byKey(const ValueKey('manage_event_save_button'));
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(repo.saveEventCallCount, 1);
      expect(repo.lastSavedData?['notify_superusers'], isTrue);
    });

    testWidgets('notify superusers reflects event model value', (tester) async {
      final event = Event(
        id: 1,
        name: 'Test Event',
        city: 'City',
        state: 'ST',
        startDateTime: DateTime(2025, 3, 1),
        endDateTime: DateTime(2025, 3, 5),
        stripNumbering: 'SequentialNumbers',
        count: 10,
        organizerId: 'test-user-id',
        notifySuperusers: false,
      );
      final repo = MockManageEventRepository(mockIsSuperUser: true);
      await tester.pumpWidget(buildTestWidget(repository: repo, event: event));
      await pumpAndWaitForInit(tester);

      final toggle = find.byKey(
        const ValueKey('manage_event_notify_superusers_switch'),
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<SwitchListTile>(toggle);
      expect(switchWidget.value, isFalse);
    });
  });
}
