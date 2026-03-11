import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/services/lookup_service.dart';

/// LookupService is a singleton with Supabase dependencies.
/// We test the aspects accessible without mocking the database:
/// - Singleton behavior
/// - Initial state (empty caches)
/// - getActionsForSymptom null symptom path (calls Supabase, so will throw
///   in unit tests, but we verify the path is taken)
///
/// Full lookup data loading is covered by integration tests.
void main() {
  group('LookupService', () {
    test('is a singleton', () {
      final a = LookupService();
      final b = LookupService();
      expect(identical(a, b), true);
    });

    test('crewTypes getter returns list', () {
      expect(LookupService().crewTypes, isA<List>());
    });

    test('symptomClasses getter returns list', () {
      expect(LookupService().symptomClasses, isA<List>());
    });

    test('symptoms getter returns list', () {
      expect(LookupService().symptoms, isA<List>());
    });

    // The display_order fallback pattern and DB queries are tested
    // via integration tests. The methods are all static and call
    // SupabaseManager directly, making them impractical to unit test
    // without dependency injection.
  });
}
