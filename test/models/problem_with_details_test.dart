import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/models/problem.dart';
import 'package:stripcall/models/problem_with_details.dart';

void main() {
  group('ProblemWithDetails', () {
    Map<String, dynamic> _baseJson() => {
          'id': 1,
          'event': 10,
          'crew': 3,
          'originator': 'user-abc',
          'strip': '5',
          'symptom': 42,
          'startdatetime': '2026-03-10T12:00:00.000Z',
          'action': null,
          'actionby': null,
          'enddatetime': null,
          'reporter_phone': null,
          'notes': null,
        };

    group('fromJson', () {
      test('parses basic problem', () {
        final pwd = ProblemWithDetails.fromJson(_baseJson());
        expect(pwd.problem.id, 1);
        expect(pwd.symptom, isNull);
        expect(pwd.action, isNull);
        expect(pwd.originator, isNull);
        expect(pwd.actionBy, isNull);
        expect(pwd.messages, isNull);
        expect(pwd.crewType, isNull);
        expect(pwd.notes, isNull);
        expect(pwd.resolvedDateTime, isNull);
        expect(pwd.smsReporter, isNull);
      });

      test('prefers _data suffixed fields for symptom', () {
        final json = _baseJson()
          ..['symptom'] = 42  // raw int for Problem.fromJson
          ..['symptom_data'] = {'id': 42, 'symptomstring': 'Blade broken'};
        final pwd = ProblemWithDetails.fromJson(json);
        expect(pwd.symptom?['symptomstring'], 'Blade broken');
      });

      test('falls back to symptom Map when no _data suffix', () {
        final json = _baseJson()
          ..['symptom'] = {'id': 42, 'symptomstring': 'Blade broken'};
        final pwd = ProblemWithDetails.fromJson(json);
        expect(pwd.symptom?['symptomstring'], 'Blade broken');
      });

      test('parses originator_data', () {
        final json = _baseJson()
          ..['originator_data'] = {
            'supabase_id': 'user-abc',
            'firstname': 'John',
            'lastname': 'Doe',
          };
        final pwd = ProblemWithDetails.fromJson(json);
        expect(pwd.originator?['firstname'], 'John');
      });

      test('parses actionby_data', () {
        final json = _baseJson()
          ..['actionby_data'] = {
            'supabase_id': 'resolver',
            'firstname': 'Jane',
            'lastname': 'Smith',
          };
        final pwd = ProblemWithDetails.fromJson(json);
        expect(pwd.actionBy?['firstname'], 'Jane');
      });

      test('parses action_data', () {
        final json = _baseJson()
          ..['action_data'] = {'id': 5, 'actionstring': 'Replaced blade'};
        final pwd = ProblemWithDetails.fromJson(json);
        expect(pwd.action?['actionstring'], 'Replaced blade');
      });

      test('parses messages_data', () {
        final json = _baseJson()
          ..['messages_data'] = [
            {'id': 1, 'message': 'hello'},
            {'id': 2, 'message': 'world'},
          ];
        final pwd = ProblemWithDetails.fromJson(json);
        expect(pwd.messages?.length, 2);
        expect(pwd.messages?[0]['message'], 'hello');
      });

      test('parses crewtype_data', () {
        final json = _baseJson()
          ..['crewtype_data'] = {'id': 1, 'crewtype': 'Armorer'};
        final pwd = ProblemWithDetails.fromJson(json);
        expect(pwd.crewType?['crewtype'], 'Armorer');
      });

      test('parses sms_reporter_data', () {
        final json = _baseJson()
          ..['sms_reporter_data'] = {'phone': '+15551234567', 'name': 'Bob'};
        final pwd = ProblemWithDetails.fromJson(json);
        expect(pwd.smsReporter?['name'], 'Bob');
      });

      test('parses notes', () {
        final json = _baseJson()..['notes'] = 'Some note';
        final pwd = ProblemWithDetails.fromJson(json);
        expect(pwd.notes, 'Some note');
      });

      test('parses enddatetime as resolvedDateTime', () {
        final json = _baseJson()..['enddatetime'] = '2026-03-10T14:00:00.000Z';
        final pwd = ProblemWithDetails.fromJson(json);
        expect(pwd.resolvedDateTime, '2026-03-10T14:00:00.000Z');
      });
    });

    group('originatorName', () {
      test('returns full name from originator data', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          originator: {'firstname': 'John', 'lastname': 'Doe'},
        );
        expect(pwd.originatorName, 'John Doe');
      });

      test('falls back to smsReporter name', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          originator: null,
          smsReporter: {'name': 'Bob Smith'},
        );
        expect(pwd.originatorName, 'Bob Smith');
      });

      test('falls back to partial phone number', () {
        final json = _baseJson()..['reporter_phone'] = '+15551234567';
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(json),
          originator: null,
          smsReporter: null,
        );
        expect(pwd.originatorName, 'SMS (***4567)');
      });

      test('shows SMS Reporter for very short phone', () {
        final json = _baseJson()..['reporter_phone'] = '123';
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(json),
          originator: null,
          smsReporter: null,
        );
        expect(pwd.originatorName, 'SMS Reporter');
      });

      test('returns null when no data available', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
        );
        expect(pwd.originatorName, isNull);
      });

      test('prefers originator over smsReporter', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          originator: {'firstname': 'John', 'lastname': 'Doe'},
          smsReporter: {'name': 'Bob'},
        );
        expect(pwd.originatorName, 'John Doe');
      });

      test('skips originator with null names', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          originator: {'firstname': null, 'lastname': null},
          smsReporter: {'name': 'Bob'},
        );
        expect(pwd.originatorName, 'Bob');
      });

      test('skips smsReporter with empty name', () {
        final json = _baseJson()..['reporter_phone'] = '+15551234567';
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(json),
          originator: null,
          smsReporter: {'name': ''},
        );
        expect(pwd.originatorName, 'SMS (***4567)');
      });
    });

    group('actionByName', () {
      test('returns full name', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          actionBy: {'firstname': 'Jane', 'lastname': 'Smith'},
        );
        expect(pwd.actionByName, 'Jane Smith');
      });

      test('returns null when no actionBy', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
        );
        expect(pwd.actionByName, isNull);
      });

      test('returns null when names are null', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          actionBy: {'firstname': null, 'lastname': null},
        );
        expect(pwd.actionByName, isNull);
      });
    });

    group('derived getters', () {
      test('id delegates to problem', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
        );
        expect(pwd.id, 1);
      });

      test('symptomString reads from symptom map', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          symptom: {'symptomstring': 'Blade broken'},
        );
        expect(pwd.symptomString, 'Blade broken');
      });

      test('actionString reads from action map', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          action: {'actionstring': 'Replaced'},
        );
        expect(pwd.actionString, 'Replaced');
      });

      test('crewTypeName reads from crewType map', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          crewType: {'id': 1, 'crewtype': 'Armorer'},
        );
        expect(pwd.crewTypeName, 'Armorer');
        expect(pwd.crewTypeId, 1);
      });

      test('isResolved returns true when resolvedDateTime set', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          resolvedDateTime: '2026-03-10T14:00:00.000Z',
        );
        expect(pwd.isResolved, true);
      });

      test('isResolved returns false when resolvedDateTime null', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
        );
        expect(pwd.isResolved, false);
      });

      test('resolvedDateTimeParsed returns DateTime', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          resolvedDateTime: '2026-03-10T14:00:00.000Z',
        );
        expect(pwd.resolvedDateTimeParsed, DateTime.utc(2026, 3, 10, 14));
      });

      test('resolvedDateTimeParsed returns null when not resolved', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
        );
        expect(pwd.resolvedDateTimeParsed, isNull);
      });
    });

    group('copyWith', () {
      test('updates specified fields', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          notes: 'old',
        );
        final copy = pwd.copyWith(notes: 'new');
        expect(copy.notes, 'new');
        expect(copy.problem.id, pwd.problem.id);
      });

      test('preserves all fields when no args', () {
        final pwd = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          symptom: {'id': 1},
          notes: 'note',
          resolvedDateTime: '2026-03-10T14:00:00.000Z',
        );
        final copy = pwd.copyWith();
        expect(copy.symptom, pwd.symptom);
        expect(copy.notes, pwd.notes);
        expect(copy.resolvedDateTime, pwd.resolvedDateTime);
      });
    });

    group('equality', () {
      test('equal when problems have same id', () {
        final p1 = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          notes: 'a',
        );
        final p2 = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
          notes: 'b',
        );
        expect(p1, equals(p2));
      });

      test('not equal when problems have different id', () {
        final p1 = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()),
        );
        final p2 = ProblemWithDetails(
          problem: Problem.fromJson(_baseJson()..['id'] = 2),
        );
        expect(p1, isNot(equals(p2)));
      });
    });
  });
}
