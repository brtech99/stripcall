import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_manager.dart';
import '../utils/debug_utils.dart';

/// Manages Supabase Realtime subscriptions and adaptive fallback polling.
///
/// Replaces the fixed 10-second polling timer with:
/// - Realtime subscriptions for instant updates (problems, messages, responders)
/// - Adaptive fallback polling that backs off when idle
/// - Snooze mode for overnight (no polling/subscriptions)
/// - Event-ended detection
class RealtimeService {
  final int eventId;
  final int? crewId;
  final bool isSuperUser;
  final VoidCallback onUpdate;
  final VoidCallback onEventEnded;
  final VoidCallback onSnooze;

  RealtimeChannel? _channel;
  Timer? _fallbackTimer;
  Timer? _snoozeCheckTimer;

  DateTime? _eventEndDateTime;
  DateTime _lastActivityTime = DateTime.now();
  bool _snoozed = false;
  bool _disposed = false;

  // Adaptive polling intervals
  static const _fastInterval = Duration(seconds: 10);
  static const _mediumInterval = Duration(seconds: 20);
  static const _slowInterval = Duration(seconds: 40);
  static const _maxInterval = Duration(seconds: 60);
  static const _backoffToMedium = Duration(minutes: 2);
  static const _backoffToSlow = Duration(minutes: 5);

  // Snooze triggers
  static const _snoozeHour = 19; // 7 PM
  static const _wakeHour = 7;    // 7 AM
  static const _snoozeIdleThreshold = Duration(hours: 1);

  Duration _currentInterval = _fastInterval;

  RealtimeService({
    required this.eventId,
    this.crewId,
    this.isSuperUser = false,
    required this.onUpdate,
    required this.onEventEnded,
    required this.onSnooze,
  });

  bool get isSnoozed => _snoozed;

  /// Start subscriptions and polling. Call after problems page init is done.
  Future<void> start({required DateTime eventEndDateTime}) async {
    _eventEndDateTime = eventEndDateTime;

    // Check if event already ended
    if (DateTime.now().isAfter(_eventEndDateTime!)) {
      onEventEnded();
      return;
    }

    _subscribeToRealtime();
    _startFallbackPolling();
    _startSnoozeCheck();

    debugLog('RealtimeService: started for event $eventId');
  }

  /// Record that activity was detected (from Realtime or polling).
  void recordActivity() {
    _lastActivityTime = DateTime.now();
    _resetToFastPolling();
  }

  /// Resume from snooze mode.
  void resumeFromSnooze() {
    if (!_snoozed) return;
    _snoozed = false;
    _lastActivityTime = DateTime.now();
    _subscribeToRealtime();
    _startFallbackPolling();
    debugLog('RealtimeService: resumed from snooze');
  }

  /// Stop everything.
  void dispose() {
    _disposed = true;
    _channel?.unsubscribe();
    _channel = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _snoozeCheckTimer?.cancel();
    _snoozeCheckTimer = null;
    debugLog('RealtimeService: disposed');
  }

  // ─── Realtime subscriptions ───────────────────────────────────────

  void _subscribeToRealtime() {
    _channel?.unsubscribe();

    try {
      _channel = SupabaseManager()
          .client
          .channel('problems_$eventId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'problem',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'event',
              value: eventId,
            ),
            callback: (payload) {
              debugLog('RealtimeService: problem change ${payload.eventType}');
              recordActivity();
              onUpdate();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'responders',
            callback: (payload) {
              debugLog('RealtimeService: new responder');
              recordActivity();
              onUpdate();
            },
          );

      // Subscribe to crew messages if user has a crew
      if (crewId != null) {
        _channel = _channel!.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'crew_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'crew',
            value: crewId!,
          ),
          callback: (payload) {
            debugLog('RealtimeService: new crew message');
            recordActivity();
            onUpdate();
          },
        );
      }

      _channel!.subscribe((status, error) {
        if (error != null) {
          debugLogError('RealtimeService: subscription error', error);
        } else {
          debugLog('RealtimeService: subscription status: $status');
        }
      });
    } catch (e) {
      debugLogError('RealtimeService: failed to subscribe', e);
      // Fall back to polling only
    }
  }

  // ─── Adaptive fallback polling ────────────────────────────────────

  void _startFallbackPolling() {
    _fallbackTimer?.cancel();
    _currentInterval = _fastInterval;
    _scheduleFallbackPoll();
  }

  void _scheduleFallbackPoll() {
    if (_disposed || _snoozed) return;

    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(_currentInterval, () {
      if (_disposed || _snoozed) return;

      // Check if event has ended
      if (_eventEndDateTime != null && DateTime.now().isAfter(_eventEndDateTime!)) {
        onEventEnded();
        return;
      }

      // Adapt interval based on time since last activity
      final idle = DateTime.now().difference(_lastActivityTime);
      if (idle > _backoffToSlow) {
        _currentInterval = _maxInterval;
      } else if (idle > _backoffToMedium) {
        _currentInterval = _slowInterval;
      } else {
        // Stay at current or move to medium
        if (_currentInterval == _fastInterval && idle > const Duration(seconds: 30)) {
          _currentInterval = _mediumInterval;
        }
      }

      debugLog(
        'RealtimeService: fallback poll (interval: ${_currentInterval.inSeconds}s, '
        'idle: ${idle.inSeconds}s)',
      );

      onUpdate();
      _scheduleFallbackPoll();
    });
  }

  void _resetToFastPolling() {
    if (_currentInterval != _fastInterval) {
      debugLog('RealtimeService: resetting to fast polling');
      _currentInterval = _fastInterval;
      _scheduleFallbackPoll(); // Reschedule with new interval
    }
  }

  // ─── Snooze / wake management ─────────────────────────────────────

  void _startSnoozeCheck() {
    _snoozeCheckTimer?.cancel();
    // Check every minute
    _snoozeCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkSnoozeConditions(),
    );
  }

  void _checkSnoozeConditions() {
    if (_disposed || _snoozed) return;

    final now = DateTime.now();

    // Check if event has ended
    if (_eventEndDateTime != null && now.isAfter(_eventEndDateTime!)) {
      onEventEnded();
      return;
    }

    // Check snooze conditions: after 7 PM + 1 hour idle
    final hour = now.hour;
    if (hour >= _snoozeHour || hour < _wakeHour) {
      final idle = now.difference(_lastActivityTime);
      if (idle >= _snoozeIdleThreshold) {
        _enterSnooze();
      }
    }
  }

  void _enterSnooze() {
    if (_snoozed) return;
    _snoozed = true;

    // Stop subscriptions and polling
    _channel?.unsubscribe();
    _channel = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;

    debugLog('RealtimeService: entering snooze mode');
    onSnooze();

    // Schedule auto-wake at 7 AM
    _scheduleAutoWake();
  }

  void _scheduleAutoWake() {
    // Calculate time until 7 AM
    final now = DateTime.now();
    var wakeTime = DateTime(now.year, now.month, now.day, _wakeHour);
    if (now.hour >= _wakeHour) {
      // Already past 7 AM today, wake tomorrow
      wakeTime = wakeTime.add(const Duration(days: 1));
    }

    final untilWake = wakeTime.difference(now);
    debugLog('RealtimeService: auto-wake scheduled in ${untilWake.inMinutes} minutes');

    // Use the snooze check timer slot for the wake timer
    _snoozeCheckTimer?.cancel();
    _snoozeCheckTimer = Timer(untilWake, () {
      if (_disposed) return;
      if (_snoozed) {
        debugLog('RealtimeService: auto-wake triggered');
        resumeFromSnooze();
        onUpdate(); // Trigger a refresh
        _startSnoozeCheck(); // Resume snooze checking
      }
    });
  }
}
