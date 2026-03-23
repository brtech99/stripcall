import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/models/crew_member.dart';

void main() {
  group('CrewMember', () {
    Map<String, dynamic> _baseJson() => {
          'id': 1,
          'crew': 10,
          'crewmember': 'user-abc',
        };

    group('fromJson', () {
      test('parses basic fields with string crewmember', () {
        final cm = CrewMember.fromJson(_baseJson());
        expect(cm.id, 1);
        expect(cm.crewId, 10);
        expect(cm.userId, 'user-abc');
        expect(cm.user, isNull);
      });

      test('parses crewmember as Map (joined data)', () {
        final json = _baseJson()
          ..['crewmember'] = {
            'supabase_id': 'joined-id',
            'firstname': 'John',
            'lastname': 'Doe',
          };
        final cm = CrewMember.fromJson(json);
        expect(cm.userId, 'joined-id');
        expect(cm.user, isNotNull);
        expect(cm.user!.firstName, 'John');
      });

      test('parses string id and crew fields', () {
        final json = _baseJson()
          ..['id'] = '99'
          ..['crew'] = '20';
        final cm = CrewMember.fromJson(json);
        expect(cm.id, 99);
        expect(cm.crewId, 20);
      });
    });

    group('toJson', () {
      test('produces correct map', () {
        final cm = CrewMember.fromJson(_baseJson());
        final json = cm.toJson();
        expect(json['id'], 1);
        expect(json['crew'], 10);
        expect(json['crewmember'], 'user-abc');
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final cm = CrewMember.fromJson(_baseJson());
        final copy = cm.copyWith(crewId: 5);
        expect(copy.crewId, 5);
        expect(copy.id, cm.id);
        expect(copy.userId, cm.userId);
      });

      test('creates identical copy when no args passed', () {
        final cm = CrewMember.fromJson(_baseJson());
        final copy = cm.copyWith();
        expect(copy.id, cm.id);
        expect(copy.crewId, cm.crewId);
        expect(copy.userId, cm.userId);
      });
    });

    group('equality', () {
      test('crew members with same id are equal', () {
        final cm1 = CrewMember.fromJson(_baseJson());
        final cm2 = CrewMember.fromJson(_baseJson()..['crewmember'] = 'other');
        expect(cm1, equals(cm2));
      });

      test('crew members with different id are not equal', () {
        final cm1 = CrewMember.fromJson(_baseJson());
        final cm2 = CrewMember.fromJson(_baseJson()..['id'] = 2);
        expect(cm1, isNot(equals(cm2)));
      });

      test('hashCode based on id', () {
        final cm1 = CrewMember.fromJson(_baseJson());
        final cm2 = CrewMember.fromJson(_baseJson());
        expect(cm1.hashCode, cm2.hashCode);
      });
    });

    test('toString contains key fields', () {
      final cm = CrewMember.fromJson(_baseJson());
      final str = cm.toString();
      expect(str, contains('CrewMember('));
      expect(str, contains('id: 1'));
      expect(str, contains('crewId: 10'));
    });
  });
}
