import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/models/crew_type.dart';

void main() {
  group('CrewType', () {
    Map<String, dynamic> _baseJson() => {
          'id': 1,
          'crewtype': 'Armorer',
        };

    group('fromJson', () {
      test('parses basic fields', () {
        final ct = CrewType.fromJson(_baseJson());
        expect(ct.id, 1);
        expect(ct.crewType, 'Armorer');
      });

      test('parses string id', () {
        final json = _baseJson()..['id'] = '42';
        final ct = CrewType.fromJson(json);
        expect(ct.id, 42);
      });

      test('defaults crewtype to empty string when null', () {
        final json = _baseJson()..['crewtype'] = null;
        final ct = CrewType.fromJson(json);
        expect(ct.crewType, '');
      });
    });

    group('toJson', () {
      test('produces correct map', () {
        final ct = CrewType.fromJson(_baseJson());
        final json = ct.toJson();
        expect(json['id'], 1);
        expect(json['crewtype'], 'Armorer');
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final ct = CrewType.fromJson(_baseJson());
        final copy = ct.copyWith(crewType: 'Medical');
        expect(copy.crewType, 'Medical');
        expect(copy.id, ct.id);
      });

      test('creates identical copy when no args passed', () {
        final ct = CrewType.fromJson(_baseJson());
        final copy = ct.copyWith();
        expect(copy.id, ct.id);
        expect(copy.crewType, ct.crewType);
      });
    });

    group('equality', () {
      test('crew types with same id are equal', () {
        final ct1 = CrewType.fromJson(_baseJson());
        final ct2 = CrewType.fromJson(_baseJson()..['crewtype'] = 'Medical');
        expect(ct1, equals(ct2));
      });

      test('crew types with different id are not equal', () {
        final ct1 = CrewType.fromJson(_baseJson());
        final ct2 = CrewType.fromJson(_baseJson()..['id'] = 2);
        expect(ct1, isNot(equals(ct2)));
      });

      test('hashCode based on id', () {
        final ct1 = CrewType.fromJson(_baseJson());
        final ct2 = CrewType.fromJson(_baseJson());
        expect(ct1.hashCode, ct2.hashCode);
      });
    });

    test('toString contains key fields', () {
      final ct = CrewType.fromJson(_baseJson());
      final str = ct.toString();
      expect(str, contains('CrewType('));
      expect(str, contains('id: 1'));
      expect(str, contains('Armorer'));
    });
  });
}
