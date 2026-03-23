import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/models/crew.dart';

void main() {
  group('Crew', () {
    Map<String, dynamic> _baseJson() => {
          'id': 1,
          'event': 10,
          'crew_chief': 'chief-abc',
          'crew_type': 3,
          'display_style': 'default',
        };

    group('fromJson', () {
      test('parses basic fields', () {
        final c = Crew.fromJson(_baseJson());
        expect(c.id, 1);
        expect(c.eventId, 10);
        expect(c.crewChiefId, 'chief-abc');
        expect(c.crewTypeId, 3);
        expect(c.displayStyle, 'default');
        expect(c.crewChief, isNull);
      });

      test('parses crew_chief as Map (joined data)', () {
        final json = _baseJson()
          ..['crew_chief'] = {'supabase_id': 'joined-id', 'firstname': 'John'};
        final c = Crew.fromJson(json);
        expect(c.crewChiefId, 'joined-id');
        expect(c.crewChief, isNotNull);
        expect(c.crewChief!['firstname'], 'John');
      });

      test('parses crew_chief as null', () {
        final json = _baseJson()..['crew_chief'] = null;
        final c = Crew.fromJson(json);
        expect(c.crewChiefId, '');
        expect(c.crewChief, isNull);
      });

      test('parses event as Map (joined data)', () {
        final json = _baseJson()..['event'] = {'id': 20, 'name': 'Test Event'};
        final c = Crew.fromJson(json);
        expect(c.eventId, 20);
      });

      test('parses string id fields', () {
        final json = _baseJson()
          ..['id'] = '99'
          ..['event'] = '20'
          ..['crew_type'] = '7';
        final c = Crew.fromJson(json);
        expect(c.id, 99);
        expect(c.eventId, 20);
        expect(c.crewTypeId, 7);
      });

      test('parses null display_style', () {
        final json = _baseJson()..['display_style'] = null;
        final c = Crew.fromJson(json);
        expect(c.displayStyle, isNull);
      });
    });

    group('toJson', () {
      test('produces correct map', () {
        final c = Crew.fromJson(_baseJson());
        final json = c.toJson();
        expect(json['id'], 1);
        expect(json['event'], 10);
        expect(json['crew_chief'], 'chief-abc');
        expect(json['crew_type'], 3);
        expect(json['display_style'], 'default');
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final c = Crew.fromJson(_baseJson());
        final copy = c.copyWith(crewTypeId: 5, displayStyle: 'compact');
        expect(copy.crewTypeId, 5);
        expect(copy.displayStyle, 'compact');
        expect(copy.id, c.id);
        expect(copy.eventId, c.eventId);
      });

      test('creates identical copy when no args passed', () {
        final c = Crew.fromJson(_baseJson());
        final copy = c.copyWith();
        expect(copy.id, c.id);
        expect(copy.crewChiefId, c.crewChiefId);
      });
    });

    group('equality', () {
      test('crews with same id are equal', () {
        final c1 = Crew.fromJson(_baseJson());
        final c2 = Crew.fromJson(_baseJson()..['crew_type'] = 99);
        expect(c1, equals(c2));
      });

      test('crews with different id are not equal', () {
        final c1 = Crew.fromJson(_baseJson());
        final c2 = Crew.fromJson(_baseJson()..['id'] = 2);
        expect(c1, isNot(equals(c2)));
      });

      test('hashCode based on id', () {
        final c1 = Crew.fromJson(_baseJson());
        final c2 = Crew.fromJson(_baseJson());
        expect(c1.hashCode, c2.hashCode);
      });
    });

    test('toString contains key fields', () {
      final c = Crew.fromJson(_baseJson());
      final str = c.toString();
      expect(str, contains('Crew('));
      expect(str, contains('id: 1'));
      expect(str, contains('crewTypeId: 3'));
    });
  });
}
