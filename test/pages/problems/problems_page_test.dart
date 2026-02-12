import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stripcall/pages/problems/problems_page.dart';
import 'package:stripcall/models/problem_with_details.dart';
import 'package:stripcall/models/problem.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProblemWithDetails _makeProblem({
  int id = 1,
  int eventId = 100,
  int crewId = 10,
  String originatorId = 'user-1',
  String strip = '1',
  int symptomId = 1,
  DateTime? startDateTime,
  String? resolvedDateTime,
  Map<String, dynamic>? symptom,
  Map<String, dynamic>? originator,
  Map<String, dynamic>? actionBy,
  Map<String, dynamic>? action,
  List<Map<String, dynamic>>? messages,
}) {
  return ProblemWithDetails(
    problem: Problem(
      id: id,
      eventId: eventId,
      crewId: crewId,
      originatorId: originatorId,
      strip: strip,
      symptomId: symptomId,
      startDateTime: startDateTime ?? DateTime(2025, 1, 1, 12, 0),
    ),
    symptom: symptom ?? {'id': symptomId, 'symptomstring': 'Test Symptom'},
    originator:
        originator ??
        {'supabase_id': originatorId, 'firstname': 'Test', 'lastname': 'User'},
    actionBy: actionBy,
    action: action,
    messages: messages,
    resolvedDateTime: resolvedDateTime,
  );
}

// ---------------------------------------------------------------------------
// Mock Repository
// ---------------------------------------------------------------------------

class MockProblemsRepository implements ProblemsRepository {
  final String? mockUserId;
  final bool mockIsSuperUser;
  final bool mockIsReferee;
  final int? mockUserCrewId;
  final String? mockUserCrewName;
  final List<ProblemWithDetails> mockProblems;
  final Map<int, List<Map<String, dynamic>>> mockResponders;
  final List<Map<String, dynamic>> mockAllCrews;
  final String? mockError;
  final Duration delay;

  // Track calls for verification
  int loadProblemsCallCount = 0;
  int goOnMyWayCallCount = 0;
  int lastGoOnMyWayProblemId = 0;

  MockProblemsRepository({
    this.mockUserId = 'test-user-id',
    this.mockIsSuperUser = false,
    this.mockIsReferee = false,
    this.mockUserCrewId,
    this.mockUserCrewName,
    this.mockProblems = const [],
    this.mockResponders = const {},
    this.mockAllCrews = const [],
    this.mockError,
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
  Future<bool> checkSuperUserStatus() async {
    await _maybeDelay();
    return mockIsSuperUser;
  }

  @override
  Future<List<Map<String, dynamic>>> loadAllCrewsForEvent(int eventId) async {
    await _maybeDelay();
    return mockAllCrews;
  }

  @override
  Future<bool> isUserRefereeForCrew(int crewId) async {
    await _maybeDelay();
    return mockIsReferee;
  }

  @override
  Future<({int? crewId, String? crewName})> getUserCrewInfo(int eventId) async {
    await _maybeDelay();
    return (crewId: mockUserCrewId, crewName: mockUserCrewName);
  }

  @override
  Future<List<ProblemWithDetails>> loadProblems({
    required int eventId,
    required String userId,
    int? crewId,
    bool isSuperUser = false,
  }) async {
    await _maybeDelay();
    loadProblemsCallCount++;
    if (mockError != null) {
      throw Exception(mockError);
    }
    return mockProblems;
  }

  @override
  Future<Map<int, List<Map<String, dynamic>>>> loadResponders(
    List<ProblemWithDetails> problems,
  ) async {
    await _maybeDelay();
    return mockResponders;
  }

  @override
  Future<List<Map<String, dynamic>>> checkForNewProblems({
    required int eventId,
    required String userId,
    required DateTime since,
    int? crewId,
    bool isSuperUser = false,
  }) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> checkForNewMessages({
    required DateTime since,
    required List<int> problemIds,
  }) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> checkForProblemUpdates({
    required DateTime since,
    required List<int> problemIds,
  }) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> checkForResolvedProblems({
    required int eventId,
    required int crewId,
    required DateTime since,
  }) async {
    return [];
  }

  @override
  Future<int?> getCrewTypeId(int crewId) async => null;

  @override
  Future<Map<String, dynamic>?> loadMissingSymptomData(int symptomId) async =>
      null;

  @override
  Future<Map<String, dynamic>?> loadMissingOriginatorData(
    String originatorId,
  ) async => null;

  @override
  Future<Map<String, dynamic>?> loadMissingResolverData(
    String actionById,
  ) async => null;

  @override
  Future<void> goOnMyWay(int problemId, String userId) async {
    await _maybeDelay();
    goOnMyWayCallCount++;
    lastGoOnMyWayProblemId = problemId;
  }

  @override
  String getProblemStatus(
    ProblemWithDetails problem,
    Map<int, List<Map<String, dynamic>>> responders,
  ) {
    if (problem.isResolved) return 'resolved';
    if (responders.containsKey(problem.id) &&
        responders[problem.id]!.isNotEmpty) {
      return 'en_route';
    }
    return 'new';
  }
}

// ---------------------------------------------------------------------------
// Test Widget Builder
// ---------------------------------------------------------------------------

Widget buildTestWidget({
  required MockProblemsRepository repository,
  int eventId = 100,
  int? crewId = 10,
  String? crewType = 'Armorer',
}) {
  return MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ProblemsPage(
            eventId: eventId,
            crewId: crewId,
            crewType: crewType,
            repository: repository,
          ),
        ),
      ],
    ),
  );
}

/// Pump widget and wait for all async initialization to complete.
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
    // Mock shared preferences channel
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

    // Initialize Supabase with mock URL (needed for SettingsMenu, UserNameDisplay, etc.)
    try {
      await Supabase.initialize(
        url: 'https://mock-url.supabase.co',
        anonKey: 'mock-key',
      );
    } catch (_) {
      // Already initialized from a prior test suite run
    }
  });

  group('ProblemsPage', () {
    testWidgets('shows loading indicator while loading', (tester) async {
      // Use zero delay so we don't leave pending timers, but mock loadProblems
      // to throw after a while to keep the loading state visible
      final repo = MockProblemsRepository(
        delay: Duration.zero,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));

      // First frame should show loading
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Let it settle
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
    });

    testWidgets('shows empty state when no problems', (tester) async {
      final repo = MockProblemsRepository(
        mockProblems: [],
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('No problems reported yet'), findsOneWidget);
    });

    testWidgets('shows referee empty state text when isReferee', (
      tester,
    ) async {
      final repo = MockProblemsRepository(
        mockProblems: [],
        mockIsReferee: true,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(
        find.text("You haven't reported any problems yet"),
        findsOneWidget,
      );
    });

    testWidgets('shows error message when loading fails', (tester) async {
      final repo = MockProblemsRepository(
        mockError: 'Network error',
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.textContaining('Failed to load problems'), findsOneWidget);
    });

    testWidgets('shows problems list when data is loaded', (tester) async {
      final problems = [
        _makeProblem(
          id: 1,
          strip: '5',
          symptom: {'id': 1, 'symptomstring': 'Broken blade'},
          originator: {
            'supabase_id': 'user-1',
            'firstname': 'John',
            'lastname': 'Doe',
          },
        ),
        _makeProblem(
          id: 2,
          strip: '12',
          symptom: {'id': 2, 'symptomstring': 'Loose wire'},
          originator: {
            'supabase_id': 'user-2',
            'firstname': 'Jane',
            'lastname': 'Smith',
          },
        ),
      ];

      final repo = MockProblemsRepository(
        mockProblems: problems,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.textContaining('Strip 5'), findsOneWidget);
      expect(find.textContaining('Broken blade'), findsOneWidget);
      expect(find.textContaining('Strip 12'), findsOneWidget);
      expect(find.textContaining('Loose wire'), findsOneWidget);
    });

    testWidgets('shows Report Problem button', (tester) async {
      final repo = MockProblemsRepository(
        mockProblems: [],
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Report Problem'), findsOneWidget);
    });

    testWidgets('shows refresh button', (tester) async {
      final repo = MockProblemsRepository(
        mockProblems: [],
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('refresh button reloads problems', (tester) async {
      final repo = MockProblemsRepository(
        mockProblems: [],
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      final initialCallCount = repo.loadProblemsCallCount;

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(repo.loadProblemsCallCount, greaterThan(initialCallCount));
    });

    testWidgets('shows app bar title with crew name', (tester) async {
      final repo = MockProblemsRepository(
        mockProblems: [],
        mockUserCrewId: 10,
        mockUserCrewName: 'Medical',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Medical'), findsOneWidget);
    });

    testWidgets('shows "My Problems" when no crew name', (tester) async {
      final repo = MockProblemsRepository(
        mockProblems: [],
        mockUserCrewId: null,
        mockUserCrewName: null,
      );
      await tester.pumpWidget(buildTestWidget(repository: repo, crewId: null));
      await pumpAndWaitForInit(tester);

      expect(find.text('My Problems'), findsOneWidget);
    });

    testWidgets('tapping problem card toggles expansion', (tester) async {
      final problems = [
        _makeProblem(
          id: 1,
          strip: '5',
          crewId: 10,
          symptom: {'id': 1, 'symptomstring': 'Broken blade'},
          originator: {
            'supabase_id': 'user-1',
            'firstname': 'John',
            'lastname': 'Doe',
          },
        ),
      ];

      final repo = MockProblemsRepository(
        mockProblems: problems,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      // Find the expand_more icon inside the ProblemCard specifically
      // (CrewMessageWindow may also have an expand_more icon)
      final problemCardFinder = find.byKey(const ValueKey('problem_card_1'));
      expect(problemCardFinder, findsOneWidget);

      // Tap the card's InkWell to expand
      final inkWellFinder = find.descendant(
        of: problemCardFinder,
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWellFinder.first);
      await tester.pumpAndSettle();

      // After expanding, should show Resolve button for crew member
      expect(find.text('Resolve'), findsOneWidget);
    });

    testWidgets('expanded problem shows On my way button for crew member', (
      tester,
    ) async {
      final problems = [
        _makeProblem(
          id: 1,
          strip: '5',
          crewId: 10,
          symptom: {'id': 1, 'symptomstring': 'Broken blade'},
          originator: {
            'supabase_id': 'other-user',
            'firstname': 'John',
            'lastname': 'Doe',
          },
        ),
      ];

      final repo = MockProblemsRepository(
        mockProblems: problems,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      // Tap to expand
      final cardFinder = find.byKey(const ValueKey('problem_card_1'));
      final inkWellFinder = find.descendant(
        of: cardFinder,
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWellFinder.first);
      await tester.pumpAndSettle();

      expect(find.text('On my way'), findsOneWidget);
      expect(find.text('Resolve'), findsOneWidget);
    });

    testWidgets('shows resolved problem with action info', (tester) async {
      final problems = [
        _makeProblem(
          id: 1,
          strip: '5',
          crewId: 10,
          resolvedDateTime: DateTime(2025, 1, 1, 13, 0).toIso8601String(),
          symptom: {'id': 1, 'symptomstring': 'Broken blade'},
          action: {'id': 1, 'actionstring': 'Replaced blade'},
          originator: {
            'supabase_id': 'user-1',
            'firstname': 'John',
            'lastname': 'Doe',
          },
          actionBy: {
            'supabase_id': 'user-2',
            'firstname': 'Jane',
            'lastname': 'Smith',
          },
        ),
      ];

      final repo = MockProblemsRepository(
        mockProblems: problems,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      // Expand
      final cardFinder = find.byKey(const ValueKey('problem_card_1'));
      final inkWellFinder = find.descendant(
        of: cardFinder,
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWellFinder.first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Replaced blade'), findsOneWidget);
      expect(find.textContaining('Jane Smith'), findsOneWidget);
    });

    testWidgets('shows "Other Crew" badge for different crew problem', (
      tester,
    ) async {
      final problems = [
        _makeProblem(
          id: 1,
          strip: '5',
          crewId: 20, // different from userCrewId
          symptom: {'id': 1, 'symptomstring': 'Broken blade'},
          originator: {
            'supabase_id': 'user-1',
            'firstname': 'John',
            'lastname': 'Doe',
          },
        ),
      ];

      final repo = MockProblemsRepository(
        mockProblems: problems,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Other Crew'), findsOneWidget);
    });

    testWidgets('super user sees crew dropdown in app bar', (tester) async {
      final crews = [
        <String, dynamic>{
          'id': 10,
          'crewtype': <String, dynamic>{'crewtype': 'Armorer'},
        },
        <String, dynamic>{
          'id': 20,
          'crewtype': <String, dynamic>{'crewtype': 'Medical'},
        },
      ];

      final repo = MockProblemsRepository(
        mockProblems: [],
        mockIsSuperUser: true,
        mockAllCrews: crews,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.byType(DropdownButton<int>), findsOneWidget);
    });

    testWidgets('shows en_route status with responder info', (tester) async {
      final problems = [
        _makeProblem(
          id: 1,
          strip: '5',
          crewId: 10,
          symptom: {'id': 1, 'symptomstring': 'Broken blade'},
          originator: {
            'supabase_id': 'user-1',
            'firstname': 'John',
            'lastname': 'Doe',
          },
        ),
      ];

      final repo = MockProblemsRepository(
        mockProblems: problems,
        mockResponders: {
          1: [
            {
              'user_id': 'user-2',
              'user': {'firstname': 'Jane', 'lastname': 'Smith'},
            },
          ],
        },
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      // Expand
      final cardFinder = find.byKey(const ValueKey('problem_card_1'));
      final inkWellFinder = find.descendant(
        of: cardFinder,
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWellFinder.first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Responding'), findsOneWidget);
      expect(find.textContaining('Jane Smith'), findsOneWidget);
    });

    testWidgets('resolved problems do not show action buttons', (tester) async {
      final problems = [
        _makeProblem(
          id: 1,
          strip: '5',
          crewId: 10,
          resolvedDateTime: DateTime(2025, 1, 1, 13, 0).toIso8601String(),
          symptom: {'id': 1, 'symptomstring': 'Broken blade'},
          action: {'id': 1, 'actionstring': 'Fixed'},
          originator: {
            'supabase_id': 'user-1',
            'firstname': 'John',
            'lastname': 'Doe',
          },
        ),
      ];

      final repo = MockProblemsRepository(
        mockProblems: problems,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      // Expand
      final cardFinder = find.byKey(const ValueKey('problem_card_1'));
      final inkWellFinder = find.descendant(
        of: cardFinder,
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWellFinder.first);
      await tester.pumpAndSettle();

      expect(find.text('On my way'), findsNothing);
      expect(find.text('Resolve'), findsNothing);
    });

    testWidgets('handles null userId gracefully', (tester) async {
      final repo = MockProblemsRepository(mockUserId: null, mockProblems: []);
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.textContaining('User not logged in'), findsOneWidget);
    });

    testWidgets('shows multiple problems in list', (tester) async {
      final problems = List.generate(
        5,
        (i) => _makeProblem(
          id: i + 1,
          strip: '${i + 1}',
          symptom: {'id': i + 1, 'symptomstring': 'Symptom ${i + 1}'},
          startDateTime: DateTime(2025, 1, 1, 12, i),
        ),
      );

      final repo = MockProblemsRepository(
        mockProblems: problems,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      for (var i = 1; i <= 5; i++) {
        expect(find.textContaining('Strip $i'), findsOneWidget);
      }
    });

    testWidgets('no "Other Crew" badge for same-crew problem', (tester) async {
      final problems = [
        _makeProblem(
          id: 1,
          strip: '5',
          crewId: 10, // same as userCrewId
          symptom: {'id': 1, 'symptomstring': 'Broken blade'},
        ),
      ];

      final repo = MockProblemsRepository(
        mockProblems: problems,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.text('Other Crew'), findsNothing);
    });

    testWidgets('shows problem reporter name in collapsed view', (
      tester,
    ) async {
      final problems = [
        _makeProblem(
          id: 1,
          strip: '5',
          symptom: {'id': 1, 'symptomstring': 'Broken blade'},
          originator: {
            'supabase_id': 'user-1',
            'firstname': 'Alice',
            'lastname': 'Wonder',
          },
        ),
      ];

      final repo = MockProblemsRepository(
        mockProblems: problems,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.textContaining('Alice Wonder'), findsOneWidget);
    });

    testWidgets('super user can see dropdown with crew options', (
      tester,
    ) async {
      final crews = [
        <String, dynamic>{
          'id': 10,
          'crewtype': <String, dynamic>{'crewtype': 'Armorer'},
        },
        <String, dynamic>{
          'id': 20,
          'crewtype': <String, dynamic>{'crewtype': 'Medical'},
        },
        <String, dynamic>{
          'id': 30,
          'crewtype': <String, dynamic>{'crewtype': 'Natloff'},
        },
      ];

      final repo = MockProblemsRepository(
        mockProblems: [],
        mockIsSuperUser: true,
        mockAllCrews: crews,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      // Tap dropdown to open it
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();

      // All crew type options should be visible
      expect(find.text('Armorer'), findsWidgets);
      expect(find.text('Medical'), findsWidgets);
      expect(find.text('Natloff'), findsWidgets);
    });

    testWidgets('problems list uses correct ValueKeys', (tester) async {
      final problems = [
        _makeProblem(id: 42, strip: '5'),
        _makeProblem(id: 99, strip: '12'),
      ];

      final repo = MockProblemsRepository(
        mockProblems: problems,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.byKey(const ValueKey('problems_list')), findsOneWidget);
      expect(find.byKey(const ValueKey('problem_card_42')), findsOneWidget);
      expect(find.byKey(const ValueKey('problem_card_99')), findsOneWidget);
    });

    testWidgets('Report Problem button has correct key', (tester) async {
      final repo = MockProblemsRepository(
        mockProblems: [],
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(
        find.byKey(const ValueKey('problems_report_button')),
        findsOneWidget,
      );
    });

    testWidgets('shows problem symptom string on card', (tester) async {
      final problems = [
        _makeProblem(
          id: 1,
          strip: '7',
          symptom: {'id': 1, 'symptomstring': 'Blade bent at guard'},
        ),
      ];

      final repo = MockProblemsRepository(
        mockProblems: problems,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.textContaining('Blade bent at guard'), findsOneWidget);
      expect(find.textContaining('Strip 7'), findsOneWidget);
    });

    testWidgets('collapse expanded card hides action buttons', (tester) async {
      final problems = [
        _makeProblem(
          id: 1,
          strip: '5',
          crewId: 10,
          symptom: {'id': 1, 'symptomstring': 'Broken'},
          originator: {
            'supabase_id': 'other-user',
            'firstname': 'John',
            'lastname': 'Doe',
          },
        ),
      ];

      final repo = MockProblemsRepository(
        mockProblems: problems,
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      final cardFinder = find.byKey(const ValueKey('problem_card_1'));
      final inkWellFinder = find.descendant(
        of: cardFinder,
        matching: find.byType(InkWell),
      );

      // Expand
      await tester.tap(inkWellFinder.first);
      await tester.pumpAndSettle();
      expect(find.text('On my way'), findsOneWidget);

      // Collapse
      await tester.tap(inkWellFinder.first);
      await tester.pumpAndSettle();
      expect(find.text('On my way'), findsNothing);
    });

    testWidgets('referee user does not see On my way button', (tester) async {
      final problems = [
        _makeProblem(
          id: 1,
          strip: '5',
          crewId: 10,
          symptom: {'id': 1, 'symptomstring': 'Broken'},
          originator: {
            'supabase_id': 'user-1',
            'firstname': 'John',
            'lastname': 'Doe',
          },
        ),
      ];

      // Referee has no crew ID (they are not a crew member)
      final repo = MockProblemsRepository(
        mockProblems: problems,
        mockIsReferee: true,
        mockUserCrewId: null,
        mockUserCrewName: null,
      );
      await tester.pumpWidget(
        buildTestWidget(repository: repo, crewId: null, crewType: null),
      );
      await pumpAndWaitForInit(tester);

      // Expand
      final cardFinder = find.byKey(const ValueKey('problem_card_1'));
      final inkWellFinder = find.descendant(
        of: cardFinder,
        matching: find.byType(InkWell),
      );
      await tester.tap(inkWellFinder.first);
      await tester.pumpAndSettle();

      // Referee without crew membership should not see On my way
      expect(find.text('On my way'), findsNothing);
    });

    testWidgets('shows check_circle_outline icon in empty state', (
      tester,
    ) async {
      final repo = MockProblemsRepository(
        mockProblems: [],
        mockUserCrewId: 10,
        mockUserCrewName: 'Armorer',
      );
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await pumpAndWaitForInit(tester);

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });
}
