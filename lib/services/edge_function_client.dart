import 'package:http/http.dart' as http;
import 'dart:convert';
import 'supabase_manager.dart';
import '../utils/debug_utils.dart';

/// Centralized client for calling Supabase Edge Functions via HTTP.
///
/// Handles authentication headers, URL construction, failover to secondary,
/// and error handling in one place instead of duplicating across services.
class EdgeFunctionClient {
  static final EdgeFunctionClient _instance = EdgeFunctionClient._internal();
  factory EdgeFunctionClient() => _instance;
  EdgeFunctionClient._internal();

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _secondaryUrl = String.fromEnvironment('SUPABASE_SECONDARY_URL');
  static const _secondaryServiceRoleKey =
      String.fromEnvironment('SUPABASE_SECONDARY_SERVICE_ROLE_KEY');

  bool get _hasSecondary => _secondaryUrl.isNotEmpty;

  /// Call an edge function with the current user's auth token.
  /// Tries primary first; falls back to secondary on failure.
  /// Returns the parsed JSON response body, or null on failure.
  Future<Map<String, dynamic>?> post(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final session = SupabaseManager().auth.currentSession;
    if (session == null) {
      debugLogError('EdgeFunctionClient: No active session for $functionName');
      return null;
    }

    // Try primary
    final primaryResult = await _tryPost(
      baseUrl: _supabaseUrl,
      apiKey: _supabaseAnonKey,
      functionName: functionName,
      body: body,
      accessToken: session.accessToken,
      label: 'primary',
    );

    if (primaryResult != null) return primaryResult;

    // Fallback to secondary
    if (_hasSecondary) {
      debugLog(
        'EdgeFunctionClient: primary failed for $functionName, trying secondary',
      );
      return _tryPost(
        baseUrl: _secondaryUrl,
        apiKey: _secondaryServiceRoleKey,
        functionName: functionName,
        body: body,
        accessToken: session.accessToken,
        label: 'secondary',
      );
    }

    return null;
  }

  /// Attempt a POST to a specific Supabase instance.
  /// Returns parsed JSON on success (status 200), null on failure.
  Future<Map<String, dynamic>?> _tryPost({
    required String baseUrl,
    required String apiKey,
    required String functionName,
    required Map<String, dynamic> body,
    required String accessToken,
    required String label,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/functions/v1/$functionName');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
              'apikey': apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return data;
      } else {
        debugLogError(
          'EdgeFunctionClient: $label $functionName returned ${response.statusCode}',
          data['error'] ?? response.body,
        );
        // Non-200 from primary still counts as "reachable" — return data
        // so caller can inspect the error. Don't fall back for app-level errors.
        return data;
      }
    } catch (e) {
      debugLogError(
        'EdgeFunctionClient: $label error calling $functionName',
        e,
      );
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
