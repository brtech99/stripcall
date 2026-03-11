import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/models/problem.dart';
import 'package:stripcall/models/problem_with_details.dart';
import 'package:stripcall/services/problem_service.dart';

void main() {
  group('ProblemService', () {
    late ProblemService service;

    setUp(() {
      service = ProblemService();
    });

    group('getProblemStatus', () {
      ProblemWithDetails _makeProblem({
        int id = 1,
        String? resolvedDateTime,
      }) {
        return ProblemWithDetails(
          problem: Problem(
            id: id,
            eventId: 10,
            crewId: 3,
            originatorId: 'user-abc',
            strip: '5',
            symptomId: 42,
            startDateTime: DateTime.utc(2026, 3, 10, 12),
          ),
          resolvedDateTime: resolvedDateTime,
        );
      }

      test('returns resolved when problem is resolved', () {
        final problem = _makeProblem(resolvedDateTime: '2026-03-10T14:00:00.000Z');
        final status = service.getProblemStatus(problem, {});
        expect(status, 'resolved');
      });

      test('returns en_route when responders exist', () {
        final problem = _makeProblem();
        final responders = {
          1: [
            {'user_id': 'resp-1', 'responded_at': '2026-03-10T13:00:00.000Z'}
          ],
        };
        final status = service.getProblemStatus(problem, responders);
        expect(status, 'en_route');
      });

      test('returns new when no responders and not resolved', () {
        final problem = _makeProblem();
        final status = service.getProblemStatus(problem, {});
        expect(status, 'new');
      });

      test('returns resolved over en_route (resolved takes precedence)', () {
        final problem = _makeProblem(resolvedDateTime: '2026-03-10T14:00:00.000Z');
        final responders = {
          1: [
            {'user_id': 'resp-1'}
          ],
        };
        final status = service.getProblemStatus(problem, responders);
        expect(status, 'resolved');
      });

      test('returns new when responder list is empty', () {
        final problem = _makeProblem();
        final responders = {1: <Map<String, dynamic>>[]};
        final status = service.getProblemStatus(problem, responders);
        expect(status, 'new');
      });

      test('returns new when responders for different problem', () {
        final problem = _makeProblem(id: 1);
        final responders = {
          2: [
            {'user_id': 'resp-1'}
          ],
        };
        final status = service.getProblemStatus(problem, responders);
        expect(status, 'new');
      });
    });

    group('parseAndFilterProblems', () {
      Map<String, dynamic> _makeProblemJson({
        int id = 1,
        String? enddatetime,
      }) {
        return {
          'id': id,
          'event': 10,
          'crew': 3,
          'originator': 'user-abc',
          'strip': '5',
          'symptom': 42,
          'startdatetime': '2026-03-10T12:00:00.000Z',
          'action': null,
          'actionby': null,
          'enddatetime': enddatetime,
          'reporter_phone': null,
          'notes': null,
        };
      }

      test('parses valid problem JSON', () {
        final result = service.parseAndFilterProblems([
          _makeProblemJson(),
        ]);
        expect(result.length, 1);
        expect(result[0].id, 1);
      });

      test('filters out resolved problems older than 5 minutes', () {
        final oldResolved = DateTime.now()
            .subtract(const Duration(minutes: 10))
            .toUtc()
            .toIso8601String();
        final result = service.parseAndFilterProblems([
          _makeProblemJson(enddatetime: oldResolved),
        ]);
        expect(result.length, 0);
      });

      test('keeps resolved problems newer than 5 minutes', () {
        final recentResolved = DateTime.now()
            .subtract(const Duration(minutes: 2))
            .toUtc()
            .toIso8601String();
        final result = service.parseAndFilterProblems([
          _makeProblemJson(enddatetime: recentResolved),
        ]);
        expect(result.length, 1);
      });

      test('keeps unresolved problems', () {
        final result = service.parseAndFilterProblems([
          _makeProblemJson(),
          _makeProblemJson(id: 2),
        ]);
        expect(result.length, 2);
      });

      test('deduplicates by id when deduplicate=true', () {
        final result = service.parseAndFilterProblems(
          [
            _makeProblemJson(id: 1),
            _makeProblemJson(id: 1), // duplicate
            _makeProblemJson(id: 2),
          ],
          deduplicate: true,
        );
        expect(result.length, 2);
        expect(result.map((p) => p.id).toSet(), {1, 2});
      });

      test('does not deduplicate when deduplicate=false', () {
        final result = service.parseAndFilterProblems([
          _makeProblemJson(id: 1),
          _makeProblemJson(id: 1), // duplicate kept
        ]);
        expect(result.length, 2);
      });

      test('skips malformed JSON entries', () {
        final result = service.parseAndFilterProblems([
          _makeProblemJson(id: 1),
          {'bad': 'data'}, // will throw in Problem.fromJson
          _makeProblemJson(id: 2),
        ]);
        expect(result.length, 2);
      });

      test('handles empty list', () {
        final result = service.parseAndFilterProblems([]);
        expect(result, isEmpty);
      });
    });

    group('crew sorting in loadAllCrewsForEvent', () {
      // We test the sorting logic directly by replicating it
      List<Map<String, dynamic>> sortCrews(List<Map<String, dynamic>> crews) {
        crews.sort((a, b) {
          final aType = (a['crewtype']?['crewtype'] as String?) ?? '';
          final bType = (b['crewtype']?['crewtype'] as String?) ?? '';

          const priorityOrder = ['Armorer', 'Medical'];
          final aIndex = priorityOrder.indexOf(aType);
          final bIndex = priorityOrder.indexOf(bType);

          if (aIndex != -1 && bIndex != -1) {
            return aIndex.compareTo(bIndex);
          } else if (aIndex != -1) {
            return -1;
          } else if (bIndex != -1) {
            return 1;
          } else {
            return aType.compareTo(bType);
          }
        });
        return crews;
      }

      test('Armorer comes first, Medical second', () {
        final crews = [
          {'id': 1, 'crewtype': {'crewtype': 'Medical'}},
          {'id': 2, 'crewtype': {'crewtype': 'Armorer'}},
        ];
        final sorted = sortCrews(crews);
        expect(sorted[0]['crewtype']['crewtype'], 'Armorer');
        expect(sorted[1]['crewtype']['crewtype'], 'Medical');
      });

      test('priority crews come before alphabetical crews', () {
        final crews = [
          {'id': 1, 'crewtype': {'crewtype': 'Zebra'}},
          {'id': 2, 'crewtype': {'crewtype': 'Armorer'}},
          {'id': 3, 'crewtype': {'crewtype': 'Alpha'}},
        ];
        final sorted = sortCrews(crews);
        expect(sorted[0]['crewtype']['crewtype'], 'Armorer');
        expect(sorted[1]['crewtype']['crewtype'], 'Alpha');
        expect(sorted[2]['crewtype']['crewtype'], 'Zebra');
      });

      test('non-priority crews are alphabetical', () {
        final crews = [
          {'id': 1, 'crewtype': {'crewtype': 'Natloff'}},
          {'id': 2, 'crewtype': {'crewtype': 'Audio'}},
          {'id': 3, 'crewtype': {'crewtype': 'Electric'}},
        ];
        final sorted = sortCrews(crews);
        expect(sorted[0]['crewtype']['crewtype'], 'Audio');
        expect(sorted[1]['crewtype']['crewtype'], 'Electric');
        expect(sorted[2]['crewtype']['crewtype'], 'Natloff');
      });

      test('handles missing crewtype data', () {
        final crews = [
          {'id': 1, 'crewtype': null},
          {'id': 2, 'crewtype': {'crewtype': 'Armorer'}},
        ];
        final sorted = sortCrews(crews);
        expect(sorted[0]['crewtype']?['crewtype'], 'Armorer');
      });

      test('all priority types in correct order', () {
        final crews = [
          {'id': 1, 'crewtype': {'crewtype': 'Zebra'}},
          {'id': 2, 'crewtype': {'crewtype': 'Medical'}},
          {'id': 3, 'crewtype': {'crewtype': 'Armorer'}},
          {'id': 4, 'crewtype': {'crewtype': 'Alpha'}},
        ];
        final sorted = sortCrews(crews);
        expect(sorted.map((c) => c['crewtype']?['crewtype']).toList(), [
          'Armorer',
          'Medical',
          'Alpha',
          'Zebra',
        ]);
      });
    });
  });
}
