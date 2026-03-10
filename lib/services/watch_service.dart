import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import '../models/problem_with_details.dart';
import '../services/supabase_manager.dart';
import '../utils/debug_utils.dart';

/// Bridges Flutter ↔ watchOS via MethodChannel and WatchConnectivity.
/// Sends problem state to the watch and receives "On my way" actions.
class WatchService {
  static final WatchService _instance = WatchService._internal();
  factory WatchService() => _instance;
  WatchService._internal();

  static const _channel = MethodChannel('us.stripcall/watch');
  bool _isListening = false;

  /// Callback invoked when the watch sends an "On my way" action.
  /// This is a fallback — normally the iOS native layer handles it directly.
  Future<void> Function(int problemId)? onWatchGoOnMyWay;

  /// Start listening for watch actions. Safe to call multiple times.
  void initialize() {
    if (_isListening || !Platform.isIOS) return;
    _isListening = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onWatchGoOnMyWay':
          final args = call.arguments as Map<dynamic, dynamic>;
          final problemId = args['problemId'] as int;
          debugLog('WatchService: received goOnMyWay for problem $problemId');
          if (onWatchGoOnMyWay != null) {
            await onWatchGoOnMyWay!(problemId);
          }
          return null;
        default:
          throw MissingPluginException('Not implemented: ${call.method}');
      }
    });
  }

  /// Push auth credentials to native iOS code so it can call the
  /// go-on-my-way edge function directly (even when Flutter is suspended).
  Future<void> syncCredentials() async {
    if (!Platform.isIOS) return;

    final session = SupabaseManager().auth.currentSession;
    final userId = SupabaseManager().auth.currentUser?.id;
    if (session == null || userId == null) return;

    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    try {
      await _channel.invokeMethod('syncCredentials', {
        'accessToken': session.accessToken,
        'userId': userId,
        'supabaseUrl': supabaseUrl,
        'supabaseAnonKey': supabaseAnonKey,
      });
    } catch (e) {
      debugLog('WatchService: error syncing credentials: $e');
    }
  }

  /// Push current problem state to the watch.
  /// Called after every poll cycle or when problems change.
  Future<void> updateProblems(
    List<ProblemWithDetails> problems,
    Map<int, List<Map<String, dynamic>>> responders,
  ) async {
    if (!Platform.isIOS) return;

    try {
      final watchProblems = problems.map((p) {
        final status = _getStatus(p, responders);
        final problemResponders = responders[p.id] ?? [];

        return {
          'id': p.id,
          'strip': p.strip,
          'symptom': p.symptomString ?? 'Unknown',
          'status': status,
          'originatorName': p.originatorName ?? 'Unknown',
          'startTime': p.startDateTime.toIso8601String(),
          'responders': problemResponders.map((r) {
            final user = r['user'] as Map<String, dynamic>?;
            return {
              'name': user != null
                  ? '${user['firstname']} ${user['lastname']}'
                  : 'Unknown',
              'respondedAt': r['responded_at']?.toString() ?? '',
            };
          }).toList(),
          'messages': (p.messages ?? [])
              .map(
                (m) => {
                  'text': m['message']?.toString() ?? '',
                  'createdAt': m['created_at']?.toString() ?? '',
                },
              )
              .toList(),
          'resolution': p.actionString,
          'resolvedBy': p.actionByName,
          'resolvedAt': p.resolvedDateTimeParsed?.toIso8601String(),
          'notes': p.notes,
        };
      }).toList();

      final jsonString = jsonEncode(watchProblems);
      await _channel.invokeMethod('updateProblems', {
        'problemsJson': jsonString,
      });
    } catch (e) {
      // Silently fail - watch may not be paired
      debugLog('WatchService: error sending to watch: $e');
    }
  }

  String _getStatus(
    ProblemWithDetails problem,
    Map<int, List<Map<String, dynamic>>> responders,
  ) {
    if (problem.isResolved) return 'resolved';
    if (responders.containsKey(problem.id) &&
        responders[problem.id]!.isNotEmpty) {
      return 'en_route';
    }
    return 'new';
  }
}
