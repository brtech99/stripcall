import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/models/problem.dart';

void main() {
  group('Problem', () {
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
        };

    group('fromJson', () {
      test('parses basic int fields', () {
        final p = Problem.fromJson(_baseJson());
        expect(p.id, 1);
        expect(p.eventId, 10);
        expect(p.crewId, 3);
        expect(p.originatorId, 'user-abc');
        expect(p.strip, '5');
        expect(p.symptomId, 42);
        expect(p.startDateTime, DateTime.utc(2026, 3, 10, 12));
        expect(p.actionId, isNull);
        expect(p.actionById, isNull);
        expect(p.endDateTime, isNull);
        expect(p.reporterPhone, isNull);
      });

      test('parses symptom as Map (joined data)', () {
        final json = _baseJson()..['symptom'] = {'id': 99, 'symptomstring': 'Blade broken'};
        final p = Problem.fromJson(json);
        expect(p.symptomId, 99);
      });

      test('parses symptom as String', () {
        final json = _baseJson()..['symptom'] = '77';
        final p = Problem.fromJson(json);
        expect(p.symptomId, 77);
      });

      test('parses null symptom as 0', () {
        final json = _baseJson()..['symptom'] = null;
        final p = Problem.fromJson(json);
        expect(p.symptomId, 0);
      });

      test('parses unparseable symptom string as 0', () {
        final json = _baseJson()..['symptom'] = 'not-a-number';
        final p = Problem.fromJson(json);
        expect(p.symptomId, 0);
      });

      test('parses action as int', () {
        final json = _baseJson()..['action'] = 5;
        final p = Problem.fromJson(json);
        expect(p.actionId, 5);
      });

      test('parses action as Map (joined data)', () {
        final json = _baseJson()..['action'] = {'id': 8, 'actionstring': 'Fixed'};
        final p = Problem.fromJson(json);
        expect(p.actionId, 8);
      });

      test('parses action as String', () {
        final json = _baseJson()..['action'] = '12';
        final p = Problem.fromJson(json);
        expect(p.actionId, 12);
      });

      test('parses originator as Map (joined data)', () {
        final json = _baseJson()
          ..['originator'] = {'supabase_id': 'joined-id', 'firstname': 'John'};
        final p = Problem.fromJson(json);
        expect(p.originatorId, 'joined-id');
      });

      test('parses originator as null', () {
        final json = _baseJson()..['originator'] = null;
        final p = Problem.fromJson(json);
        expect(p.originatorId, '');
      });

      test('parses actionby as String', () {
        final json = _baseJson()..['actionby'] = 'resolver-id';
        final p = Problem.fromJson(json);
        expect(p.actionById, 'resolver-id');
      });

      test('parses actionby as Map (joined data)', () {
        final json = _baseJson()
          ..['actionby'] = {'supabase_id': 'resolver-id', 'firstname': 'Jane'};
        final p = Problem.fromJson(json);
        expect(p.actionById, 'resolver-id');
      });

      test('parses actionby Map with empty supabase_id as null', () {
        final json = _baseJson()
          ..['actionby'] = {'supabase_id': '', 'firstname': 'Jane'};
        final p = Problem.fromJson(json);
        expect(p.actionById, isNull);
      });

      test('parses enddatetime when present', () {
        final json = _baseJson()..['enddatetime'] = '2026-03-10T14:00:00.000Z';
        final p = Problem.fromJson(json);
        expect(p.endDateTime, DateTime.utc(2026, 3, 10, 14));
      });

      test('parses reporter_phone', () {
        final json = _baseJson()..['reporter_phone'] = '+15551234567';
        final p = Problem.fromJson(json);
        expect(p.reporterPhone, '+15551234567');
      });

      test('parses string id and event fields', () {
        final json = _baseJson()
          ..['id'] = '99'
          ..['event'] = '20'
          ..['crew'] = '7';
        final p = Problem.fromJson(json);
        expect(p.id, 99);
        expect(p.eventId, 20);
        expect(p.crewId, 7);
      });

      test('defaults to 0 for unparseable id', () {
        final json = _baseJson()..['id'] = 'bad';
        final p = Problem.fromJson(json);
        expect(p.id, 0);
      });
    });

    group('toJson', () {
      test('produces correct map', () {
        final p = Problem.fromJson(_baseJson());
        final json = p.toJson();
        expect(json['id'], 1);
        expect(json['event'], 10);
        expect(json['crew'], 3);
        expect(json['originator'], 'user-abc');
        expect(json['strip'], '5');
        expect(json['symptom'], 42);
        expect(json['startdatetime'], isA<String>());
        expect(json['action'], isNull);
        expect(json['actionby'], isNull);
        expect(json['enddatetime'], isNull);
        expect(json['reporter_phone'], isNull);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final p = Problem.fromJson(_baseJson());
        final copy = p.copyWith(strip: '10', actionId: 5);
        expect(copy.strip, '10');
        expect(copy.actionId, 5);
        expect(copy.id, p.id); // unchanged
        expect(copy.crewId, p.crewId); // unchanged
      });

      test('creates identical copy when no args passed', () {
        final p = Problem.fromJson(_baseJson());
        final copy = p.copyWith();
        expect(copy.id, p.id);
        expect(copy.strip, p.strip);
        expect(copy.symptomId, p.symptomId);
      });
    });

    group('equality', () {
      test('problems with same id are equal', () {
        final p1 = Problem.fromJson(_baseJson());
        final p2 = Problem.fromJson(_baseJson()..['strip'] = '99');
        expect(p1, equals(p2));
      });

      test('problems with different id are not equal', () {
        final p1 = Problem.fromJson(_baseJson());
        final p2 = Problem.fromJson(_baseJson()..['id'] = 2);
        expect(p1, isNot(equals(p2)));
      });

      test('hashCode based on id', () {
        final p1 = Problem.fromJson(_baseJson());
        final p2 = Problem.fromJson(_baseJson());
        expect(p1.hashCode, p2.hashCode);
      });
    });

    test('toString contains key fields', () {
      final p = Problem.fromJson(_baseJson());
      final str = p.toString();
      expect(str, contains('Problem('));
      expect(str, contains('id: 1'));
      expect(str, contains('strip: 5'));
    });
  });
}
