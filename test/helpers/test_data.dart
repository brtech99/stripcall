import 'package:stripcall/models/event.dart';

class TestData {
  static final mockUser = {
    'id': 'test-user-id',
    'firstname': 'Test',
    'lastname': 'User',
    'email': 'test@example.com',
  };

  static final mockEvent = Event(
    id: 1,
    name: 'Test Event',
    city: 'Test City',
    state: 'Test State',
    startDateTime: DateTime.now(),
    endDateTime: DateTime.now().add(const Duration(days: 1)),
    stripNumbering: 'SequentialNumbers',
    count: 10,
    organizerId: 'test-user-id',
  );

  static final mockCrew = {
    'id': 'test-crew-id',
    'event': mockEvent.id,
    'crewchief': mockUser['id'],
    'crewtype': 'Test Crew Type',
  };

  static final mockCrewMember = {
    'id': 'test-crew-member-id',
    'crew': mockCrew['id'],
    'user': mockUser['id'],
  };

  static final mockProblem = {
    'id': 'test-problem-id',
    'event': mockEvent.id,
    'crew': mockCrew['id'],
    'reporter': mockUser['id'],
    'description': 'Test problem description',
    'status': 'active',
    'created_at': DateTime.now().toIso8601String(),
  };
} 