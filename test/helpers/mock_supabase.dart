import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'test_data.dart';

// ignore: must_be_immutable
class MockSupabaseClient extends Mock implements SupabaseClient {
  final Map<String, List<Map<String, dynamic>>> mockData;

  MockSupabaseClient() : mockData = {
    'users': [TestData.mockUser],
    'events': [TestData.mockEvent.toJson()],
    'crews': [TestData.mockCrew],
    'crewmembers': [TestData.mockCrewMember],
    'problems': [TestData.mockProblem],
  };
}

// ignore: must_be_immutable
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {
  final Map<String, List<Map<String, dynamic>>> mockData;

  MockSupabaseQueryBuilder(this.mockData);
}

// ignore: must_be_immutable
class MockPostgrestFilterBuilder<T> extends Mock implements PostgrestFilterBuilder<T> {
  final Map<String, List<Map<String, dynamic>>> mockData;
  MockPostgrestFilterBuilder(this.mockData);

  Future<T> execute() async => mockData.values.expand((x) => x).toList() as T;
}

// ignore: must_be_immutable
class MockPostgrestTransformBuilder<T> extends Mock implements PostgrestTransformBuilder<T> {
  final Map<String, List<Map<String, dynamic>>> mockData;
  MockPostgrestTransformBuilder(this.mockData);

  Future<T> execute() async => mockData.values.expand((x) => x).toList() as T;
} 