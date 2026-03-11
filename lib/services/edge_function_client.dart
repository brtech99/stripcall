import 'package:http/http.dart' as http;
import 'dart:convert';
import 'supabase_manager.dart';
import '../utils/debug_utils.dart';

/// Centralized client for calling Supabase Edge Functions via HTTP.
///
/// Handles authentication headers, URL construction, and error handling
/// in one place instead of duplicating across services.
class EdgeFunctionClient {
  static final EdgeFunctionClient _instance = EdgeFunctionClient._internal();
  factory EdgeFunctionClient() => _instance;
  EdgeFunctionClient._internal();

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Call an edge function with the current user's auth token.
  /// Returns the parsed JSON response body, or null on failure.
  Future<Map<String, dynamic>?> post(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    try {
      final session = SupabaseManager().auth.currentSession;
      if (session == null) {
        debugLogError('EdgeFunctionClient: No active session for $functionName');
        return null;
      }

      final url = Uri.parse('$_supabaseUrl/functions/v1/$functionName');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': _supabaseAnonKey,
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return data;
      } else {
        debugLogError(
          'EdgeFunctionClient: $functionName returned ${response.statusCode}',
          data['error'] ?? response.body,
        );
        return data;
      }
    } catch (e) {
      debugLogError('EdgeFunctionClient: Error calling $functionName', e);
      return null;
    }
  }

  /// Fire-and-forget edge function call. Logs errors but doesn't throw.
  void postFireAndForget(String functionName, Map<String, dynamic> body) {
    post(functionName, body).catchError((e) {
      debugLogError('EdgeFunctionClient: Fire-and-forget error for $functionName', e);
      return null;
    });
  }
}
