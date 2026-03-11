import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/services/edge_function_client.dart';

/// EdgeFunctionClient is a singleton that depends on SupabaseManager().auth
/// and makes real HTTP calls. We test the aspects we can without mocking:
/// - postFireAndForget doesn't throw
/// - post returns null when session is missing (SupabaseManager not initialized)
///
/// Full integration testing of edge function calls is covered by the
/// integration test suite against local Supabase.
void main() {
  group('EdgeFunctionClient', () {
    late EdgeFunctionClient client;

    setUp(() {
      client = EdgeFunctionClient();
    });

    test('is a singleton', () {
      final a = EdgeFunctionClient();
      final b = EdgeFunctionClient();
      expect(identical(a, b), true);
    });

    test('post returns null when no active session', () async {
      // SupabaseManager is not initialized in unit tests,
      // so auth.currentSession will throw, which post catches → null
      final result = await client.post('test-fn', {'key': 'value'});
      expect(result, isNull);
    });

    test('postFireAndForget does not throw', () {
      // Should silently handle the missing session error
      expect(
        () => client.postFireAndForget('test-fn', {'key': 'value'}),
        returnsNormally,
      );
    });
  });
}
