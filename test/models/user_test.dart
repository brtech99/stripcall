import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/models/user.dart';

void main() {
  group('User', () {
    Map<String, dynamic> _baseJson() => {
          'supabase_id': 'user-abc',
          'firstname': 'John',
          'lastname': 'Doe',
          'phonenbr': '+15551234567',
          'superuser': false,
          'organizer': true,
        };

    group('fromJson', () {
      test('parses basic fields', () {
        final u = User.fromJson(_baseJson());
        expect(u.supabaseId, 'user-abc');
        expect(u.firstName, 'John');
        expect(u.lastName, 'Doe');
        expect(u.phoneNumber, '+15551234567');
        expect(u.isSuperUser, false);
        expect(u.isOrganizer, true);
      });

      test('parses alternative key names (id, first_name, last_name, phone_number)', () {
        final json = {
          'id': 'user-xyz',
          'first_name': 'Jane',
          'last_name': 'Smith',
          'phone_number': '+15559999999',
          'superuser': true,
          'organizer': false,
        };
        final u = User.fromJson(json);
        expect(u.supabaseId, 'user-xyz');
        expect(u.firstName, 'Jane');
        expect(u.lastName, 'Smith');
        expect(u.phoneNumber, '+15559999999');
      });

      test('defaults supabaseId to empty string when missing', () {
        final json = <String, dynamic>{
          'superuser': false,
          'organizer': false,
        };
        final u = User.fromJson(json);
        expect(u.supabaseId, '');
      });

      test('defaults superuser and organizer to false when null', () {
        final json = _baseJson()
          ..['superuser'] = null
          ..['organizer'] = null;
        final u = User.fromJson(json);
        expect(u.isSuperUser, false);
        expect(u.isOrganizer, false);
      });

      test('parses null name fields', () {
        final json = _baseJson()
          ..['firstname'] = null
          ..['lastname'] = null
          ..['phonenbr'] = null;
        final u = User.fromJson(json);
        expect(u.firstName, isNull);
        expect(u.lastName, isNull);
        expect(u.phoneNumber, isNull);
      });
    });

    group('toJson', () {
      test('produces correct map', () {
        final u = User.fromJson(_baseJson());
        final json = u.toJson();
        expect(json['supabase_id'], 'user-abc');
        expect(json['firstname'], 'John');
        expect(json['lastname'], 'Doe');
        expect(json['phonenbr'], '+15551234567');
        expect(json['superuser'], false);
        expect(json['organizer'], true);
      });
    });

    group('computed properties', () {
      test('fullName returns first and last', () {
        final u = User.fromJson(_baseJson());
        expect(u.fullName, 'John Doe');
      });

      test('fullName returns Unknown User when both empty', () {
        final u = User(supabaseId: 'x');
        expect(u.fullName, 'Unknown User');
      });

      test('fullName returns only first when last is null', () {
        final u = User(supabaseId: 'x', firstName: 'John');
        expect(u.fullName, 'John');
      });

      test('fullName returns only last when first is null', () {
        final u = User(supabaseId: 'x', lastName: 'Doe');
        expect(u.fullName, 'Doe');
      });

      test('lastNameFirstName returns last, first format', () {
        final u = User.fromJson(_baseJson());
        expect(u.lastNameFirstName, 'Doe, John');
      });

      test('lastNameFirstName returns Unknown User when both empty', () {
        final u = User(supabaseId: 'x');
        expect(u.lastNameFirstName, 'Unknown User');
      });

      test('hasCompleteName is true when both names present', () {
        final u = User.fromJson(_baseJson());
        expect(u.hasCompleteName, true);
      });

      test('hasCompleteName is false when first name missing', () {
        final u = User(supabaseId: 'x', lastName: 'Doe');
        expect(u.hasCompleteName, false);
      });

      test('hasRole is true when superuser', () {
        final u = User(supabaseId: 'x', isSuperUser: true);
        expect(u.hasRole, true);
      });

      test('hasRole is true when organizer', () {
        final u = User(supabaseId: 'x', isOrganizer: true);
        expect(u.hasRole, true);
      });

      test('hasRole is false when neither', () {
        final u = User(supabaseId: 'x');
        expect(u.hasRole, false);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final u = User.fromJson(_baseJson());
        final copy = u.copyWith(firstName: 'Jane', isSuperUser: true);
        expect(copy.firstName, 'Jane');
        expect(copy.isSuperUser, true);
        expect(copy.supabaseId, u.supabaseId);
        expect(copy.lastName, u.lastName);
      });

      test('creates identical copy when no args passed', () {
        final u = User.fromJson(_baseJson());
        final copy = u.copyWith();
        expect(copy.supabaseId, u.supabaseId);
        expect(copy.firstName, u.firstName);
      });
    });

    group('equality', () {
      test('users with same supabaseId are equal', () {
        final u1 = User.fromJson(_baseJson());
        final u2 = User.fromJson(_baseJson()..['firstname'] = 'Other');
        expect(u1, equals(u2));
      });

      test('users with different supabaseId are not equal', () {
        final u1 = User.fromJson(_baseJson());
        final u2 = User.fromJson(_baseJson()..['supabase_id'] = 'user-xyz');
        expect(u1, isNot(equals(u2)));
      });

      test('hashCode based on supabaseId', () {
        final u1 = User.fromJson(_baseJson());
        final u2 = User.fromJson(_baseJson());
        expect(u1.hashCode, u2.hashCode);
      });
    });

    test('toString contains key fields', () {
      final u = User.fromJson(_baseJson());
      final str = u.toString();
      expect(str, contains('User('));
      expect(str, contains('supabaseId: user-abc'));
      expect(str, contains('John Doe'));
    });
  });
}
