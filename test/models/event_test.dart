import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/models/event.dart';

void main() {
  group('Event', () {
    Map<String, dynamic> _baseJson() => {
          'id': 1,
          'name': 'NAC 2026',
          'city': 'Salt Lake City',
          'state': 'UT',
          'startdatetime': '2026-06-01T08:00:00.000Z',
          'enddatetime': '2026-06-05T18:00:00.000Z',
          'stripnumbering': 'A1-A40',
          'count': 40,
          'organizer': 'org-abc',
          'use_sms': true,
          'notify_superusers': false,
        };

    group('fromJson', () {
      test('parses basic fields', () {
        final e = Event.fromJson(_baseJson());
        expect(e.id, 1);
        expect(e.name, 'NAC 2026');
        expect(e.city, 'Salt Lake City');
        expect(e.state, 'UT');
        expect(e.startDateTime, DateTime.utc(2026, 6, 1, 8));
        expect(e.endDateTime, DateTime.utc(2026, 6, 5, 18));
        expect(e.stripNumbering, 'A1-A40');
        expect(e.count, 40);
        expect(e.organizerId, 'org-abc');
        expect(e.organizer, isNull);
        expect(e.useSms, true);
        expect(e.notifySuperusers, false);
      });

      test('parses organizer as Map (joined data)', () {
        final json = _baseJson()
          ..['organizer'] = {'supabase_id': 'joined-id', 'firstname': 'Jane'};
        final e = Event.fromJson(json);
        expect(e.organizerId, 'joined-id');
        expect(e.organizer, isNotNull);
        expect(e.organizer!['firstname'], 'Jane');
      });

      test('parses organizer as null', () {
        final json = _baseJson()..['organizer'] = null;
        final e = Event.fromJson(json);
        expect(e.organizerId, '');
        expect(e.organizer, isNull);
      });

      test('parses string id', () {
        final json = _baseJson()..['id'] = '99';
        final e = Event.fromJson(json);
        expect(e.id, 99);
      });

      test('parses count as string', () {
        final json = _baseJson()..['count'] = '25';
        final e = Event.fromJson(json);
        expect(e.count, 25);
      });

      test('defaults count to 0 when null', () {
        final json = _baseJson()..['count'] = null;
        final e = Event.fromJson(json);
        expect(e.count, 0);
      });

      test('defaults use_sms to false when null', () {
        final json = _baseJson()..['use_sms'] = null;
        final e = Event.fromJson(json);
        expect(e.useSms, false);
      });

      test('defaults notify_superusers to true when null', () {
        final json = _baseJson()..['notify_superusers'] = null;
        final e = Event.fromJson(json);
        expect(e.notifySuperusers, true);
      });

      test('defaults name to empty string when null', () {
        final json = _baseJson()..['name'] = null;
        final e = Event.fromJson(json);
        expect(e.name, '');
      });
    });

    group('toJson', () {
      test('produces correct map', () {
        final e = Event.fromJson(_baseJson());
        final json = e.toJson();
        expect(json['id'], 1);
        expect(json['name'], 'NAC 2026');
        expect(json['city'], 'Salt Lake City');
        expect(json['state'], 'UT');
        expect(json['startdatetime'], isA<String>());
        expect(json['enddatetime'], isA<String>());
        expect(json['stripnumbering'], 'A1-A40');
        expect(json['count'], 40);
        expect(json['organizer'], 'org-abc');
        expect(json['use_sms'], true);
        expect(json['notify_superusers'], false);
      });
    });

    test('toString contains key fields', () {
      final e = Event.fromJson(_baseJson());
      final str = e.toString();
      expect(str, contains('Event('));
      expect(str, contains('id: 1'));
      expect(str, contains('NAC 2026'));
    });
  });
}
