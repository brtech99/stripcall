import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/pages/problems/problems_state.dart';
import 'package:stripcall/models/problem_with_details.dart';
import 'package:stripcall/models/problem.dart';

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
  Map<String, dynamic>? action,
  Map<String, dynamic>? originator,
  Map<String, dynamic>? actionBy,
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
    action: action,
    originator:
        originator ??
        {'supabase_id': originatorId, 'firstname': 'Test', 'lastname': 'User'},
    actionBy: actionBy,
    messages: messages,
    resolvedDateTime: resolvedDateTime,
  );
}

void main() {
  group('ProblemsPageState - constructor defaults', () {
    test('has correct default values', () {
      const state = ProblemsPageState();

      expect(state.problems, isEmpty);
      expect(state.responders, isEmpty);
      expect(state.expandedProblems, isEmpty);
      expect(state.isLoading, isTrue);
      expect(state.error, isNull);
      expect(state.isReferee, isFalse);
      expect(state.userCrewId, isNull);
      expect(state.userCrewName, isNull);
      expect(state.isSuperUser, isFalse);
      expect(state.allCrews, isEmpty);
      expect(state.selectedCrewId, isNull);
    });
  });

  group('ProblemsPageState - getActiveCrewId', () {
    test('returns widgetCrewId when not super user', () {
      const state = ProblemsPageState(isSuperUser: false);
      expect(state.getActiveCrewId(42), 42);
    });

    test('returns null when not super user and widgetCrewId is null', () {
      const state = ProblemsPageState(isSuperUser: false);
      expect(state.getActiveCrewId(null), isNull);
    });

    test('returns selectedCrewId when super user', () {
      const state = ProblemsPageState(isSuperUser: true, selectedCrewId: 99);
      expect(state.getActiveCrewId(42), 99);
    });

    test('returns null when super user and no selectedCrewId', () {
      const state = ProblemsPageState(isSuperUser: true);
      expect(state.getActiveCrewId(42), isNull);
    });
  });

  group('ProblemsPageState - shouldShowCrewMessageWindow', () {
    test(
      'returns false when activeCrewId is null (non-super, no widget crew)',
      () {
        const state = ProblemsPageState(isSuperUser: false);
        expect(state.shouldShowCrewMessageWindow(null), isFalse);
      },
    );

    test('returns true when super user with selected crew', () {
      const state = ProblemsPageState(isSuperUser: true, selectedCrewId: 10);
      expect(state.shouldShowCrewMessageWindow(null), isTrue);
    });

    test('returns true when non-referee crew member with widgetCrewId', () {
      const state = ProblemsPageState(isReferee: false);
      expect(state.shouldShowCrewMessageWindow(10), isTrue);
    });

    test('returns false when referee with widgetCrewId', () {
      const state = ProblemsPageState(isReferee: true);
      expect(state.shouldShowCrewMessageWindow(10), isFalse);
    });

    test('returns false when non-referee without widgetCrewId', () {
      const state = ProblemsPageState(isReferee: false);
      expect(state.shouldShowCrewMessageWindow(null), isFalse);
    });
  });

  group('ProblemsPageState - copyWith', () {
    test('copies all fields correctly', () {
      final problems = [_makeProblem(id: 1)];
      final responders = {
        1: [
          {'user_id': 'u1'},
        ],
      };
      final expanded = {1};
      final crews = [
        {'id': 1, 'crewtype': 'Armorer'},
      ];

      final state = ProblemsPageState(
        problems: problems,
        responders: responders,
        expandedProblems: expanded,
        isLoading: false,
        error: 'some error',
        isReferee: true,
        userCrewId: 5,
        userCrewName: 'Medical',
        isSuperUser: true,
        allCrews: crews,
        selectedCrewId: 1,
      );

      final copy = state.copyWith();
      expect(copy.problems, problems);
      expect(copy.responders, responders);
      expect(copy.expandedProblems, expanded);
      expect(copy.isLoading, isFalse);
      expect(copy.error, 'some error');
      expect(copy.isReferee, isTrue);
      expect(copy.userCrewId, 5);
      expect(copy.userCrewName, 'Medical');
      expect(copy.isSuperUser, isTrue);
      expect(copy.allCrews, crews);
      expect(copy.selectedCrewId, 1);
    });

    test('overrides specific fields', () {
      const state = ProblemsPageState(isLoading: true, error: 'err');
      final updated = state.copyWith(isLoading: false, error: 'new err');
      expect(updated.isLoading, isFalse);
      expect(updated.error, 'new err');
    });

    test('clearError sets error to null', () {
      const state = ProblemsPageState(error: 'some error');
      final updated = state.copyWith(clearError: true);
      expect(updated.error, isNull);
    });

    test('clearError is overridden by explicit error', () {
      const state = ProblemsPageState(error: 'old');
      // When clearError is true but error is also provided, clearError wins
      // because clearError is checked first in the ternary
      final updated = state.copyWith(clearError: true, error: 'new');
      expect(updated.error, isNull);
    });

    test('clearUserCrewId sets userCrewId to null', () {
      const state = ProblemsPageState(userCrewId: 5);
      final updated = state.copyWith(clearUserCrewId: true);
      expect(updated.userCrewId, isNull);
    });

    test('clearUserCrewName sets userCrewName to null', () {
      const state = ProblemsPageState(userCrewName: 'Medical');
      final updated = state.copyWith(clearUserCrewName: true);
      expect(updated.userCrewName, isNull);
    });

    test('clearSelectedCrewId sets selectedCrewId to null', () {
      const state = ProblemsPageState(selectedCrewId: 10);
      final updated = state.copyWith(clearSelectedCrewId: true);
      expect(updated.selectedCrewId, isNull);
    });
  });

  group('ProblemsPageState - addProblem', () {
    test('adds a problem to empty list', () {
      const state = ProblemsPageState();
      final problem = _makeProblem(id: 1);
      final updated = state.addProblem(problem);

      expect(updated.problems, hasLength(1));
      expect(updated.problems.first.id, 1);
    });

    test('does not add duplicate problem', () {
      final problem = _makeProblem(id: 1);
      final state = ProblemsPageState(problems: [problem]);
      final updated = state.addProblem(problem);

      expect(identical(updated, state), isTrue);
    });

    test('sorts problems by startDateTime descending after add', () {
      final older = _makeProblem(id: 1, startDateTime: DateTime(2025, 1, 1));
      final newer = _makeProblem(id: 2, startDateTime: DateTime(2025, 1, 2));
      final state = ProblemsPageState(problems: [older]);
      final updated = state.addProblem(newer);

      expect(updated.problems, hasLength(2));
      expect(updated.problems[0].id, 2); // newer first
      expect(updated.problems[1].id, 1); // older second
    });
  });

  group('ProblemsPageState - updateProblem', () {
    test('updates an existing problem', () {
      final problem = _makeProblem(id: 1);
      final state = ProblemsPageState(problems: [problem]);
      final updated = state.updateProblem(
        1,
        (p) => p.copyWith(
          resolvedDateTime: DateTime(2025, 1, 2).toIso8601String(),
        ),
      );

      expect(updated.problems.first.isResolved, isTrue);
    });

    test('returns same state when problem not found', () {
      final state = ProblemsPageState(problems: [_makeProblem(id: 1)]);
      final updated = state.updateProblem(
        999,
        (p) => p.copyWith(notes: 'should not happen'),
      );

      expect(identical(updated, state), isTrue);
    });
  });

  group('ProblemsPageState - removeProblemsWhere', () {
    test('removes matching problems', () {
      final p1 = _makeProblem(id: 1, crewId: 10);
      final p2 = _makeProblem(id: 2, crewId: 20);
      final state = ProblemsPageState(problems: [p1, p2]);
      final updated = state.removeProblemsWhere((p) => p.crewId == 10);

      expect(updated.problems, hasLength(1));
      expect(updated.problems.first.id, 2);
    });

    test('returns same state when no problems match', () {
      final state = ProblemsPageState(
        problems: [_makeProblem(id: 1, crewId: 10)],
      );
      final updated = state.removeProblemsWhere((p) => p.crewId == 999);

      expect(identical(updated, state), isTrue);
    });

    test('handles removing all problems', () {
      final state = ProblemsPageState(
        problems: [_makeProblem(id: 1), _makeProblem(id: 2)],
      );
      final updated = state.removeProblemsWhere((_) => true);
      expect(updated.problems, isEmpty);
    });
  });

  group('ProblemsPageState - toggleProblemExpansion', () {
    test('expands a collapsed problem', () {
      const state = ProblemsPageState();
      final updated = state.toggleProblemExpansion(1);

      expect(updated.expandedProblems, contains(1));
    });

    test('collapses an expanded problem', () {
      final state = ProblemsPageState(expandedProblems: {1, 2});
      final updated = state.toggleProblemExpansion(1);

      expect(updated.expandedProblems, isNot(contains(1)));
      expect(updated.expandedProblems, contains(2));
    });

    test('does not modify original set', () {
      final original = {1, 2};
      final state = ProblemsPageState(expandedProblems: original);
      state.toggleProblemExpansion(1);

      expect(original, contains(1)); // original unchanged
    });
  });

  group('ProblemsPageState - addResponder', () {
    test('adds a responder to a new problem', () {
      const state = ProblemsPageState();
      final responder = {'user_id': 'u1', 'problem': 1};
      final updated = state.addResponder(1, responder);

      expect(updated.responders[1], hasLength(1));
      expect(updated.responders[1]!.first['user_id'], 'u1');
    });

    test('appends a responder to existing problem responders', () {
      final state = ProblemsPageState(
        responders: {
          1: [
            {'user_id': 'u1'},
          ],
        },
      );
      final updated = state.addResponder(1, {'user_id': 'u2'});

      expect(updated.responders[1], hasLength(2));
      expect(updated.responders[1]![1]['user_id'], 'u2');
    });

    test('does not modify other problem responders', () {
      final state = ProblemsPageState(
        responders: {
          1: [
            {'user_id': 'u1'},
          ],
          2: [
            {'user_id': 'u2'},
          ],
        },
      );
      final updated = state.addResponder(1, {'user_id': 'u3'});

      expect(updated.responders[2], hasLength(1));
    });
  });

  group('ProblemsPageState - addMessageToProblem', () {
    test('adds a message to a problem', () {
      final problem = _makeProblem(id: 1, messages: []);
      final state = ProblemsPageState(problems: [problem]);
      final message = {'id': 100, 'problem': 1, 'message': 'Hello'};
      final updated = state.addMessageToProblem(1, message);

      expect(updated.problems.first.messages, hasLength(1));
      expect(updated.problems.first.messages!.first['message'], 'Hello');
    });

    test('does not add duplicate message', () {
      final problem = _makeProblem(
        id: 1,
        messages: [
          {'id': 100, 'message': 'Hello'},
        ],
      );
      final state = ProblemsPageState(problems: [problem]);
      final message = {'id': 100, 'message': 'Hello again'};
      final updated = state.addMessageToProblem(1, message);

      expect(identical(updated, state), isTrue);
    });

    test('returns same state when problem not found', () {
      final state = ProblemsPageState(problems: [_makeProblem(id: 1)]);
      final message = {'id': 100, 'problem': 999, 'message': 'Hello'};
      final updated = state.addMessageToProblem(999, message);

      expect(identical(updated, state), isTrue);
    });

    test('handles null messages list on problem', () {
      final problem = _makeProblem(id: 1, messages: null);
      final state = ProblemsPageState(problems: [problem]);
      final message = {'id': 100, 'problem': 1, 'message': 'Hello'};
      final updated = state.addMessageToProblem(1, message);

      // When messages is null, existing check uses ?? []
      expect(updated.problems.first.messages, hasLength(1));
    });
  });
}
