import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pending_transaction.dart';
import '../utils/debug_utils.dart';
import 'transaction_log.dart';

/// Manages dual Supabase clients (Cloud primary + self-hosted secondary).
///
/// - Reads go to primary, falling back to secondary if primary is unhealthy.
/// - Writes go to both; failures are queued in [TransactionLog] for replay.
/// - Auth always goes through primary (Cloud only).
/// - Secondary uses the service role key (bypasses RLS).
class SupabaseManager {
  static final SupabaseManager _instance = SupabaseManager._internal();
  factory SupabaseManager() => _instance;
  SupabaseManager._internal();

  /// Test-only constructor that bypasses the singleton.
  @visibleForTesting
  SupabaseManager.forTesting();

  late SupabaseClient _primary;
  SupabaseClient? _secondary;
  late TransactionLog _transactionLog;

  bool _primaryHealthy = true;
  bool _secondaryHealthy = true;
  bool _initialized = false;
  Timer? _healthCheckTimer;
  Timer? _replayTimer;

  // Callback for UI health indicator
  ValueNotifier<HealthStatus> healthStatus = ValueNotifier(
    HealthStatus.allHealthy,
  );

  /// Whether a secondary instance is configured.
  bool get hasSecondary => _secondary != null;

  bool get primaryHealthy => _primaryHealthy;
  bool get secondaryHealthy => _secondaryHealthy;

  @visibleForTesting
  set primaryHealthyForTest(bool value) {
    _primaryHealthy = value;
    _updateHealthStatus();
  }

  @visibleForTesting
  set secondaryHealthyForTest(bool value) {
    _secondaryHealthy = value;
    _updateHealthStatus();
  }

  /// The primary client — use for auth and for reads when healthy.
  SupabaseClient get client => _primary;

  /// Auth always goes through primary (Cloud).
  GoTrueClient get auth => _primary.auth;

  /// Initialize with primary and optional secondary client.
  Future<void> initialize({
    required SupabaseClient primary,
    SupabaseClient? secondary,
  }) async {
    _primary = primary;
    _secondary = secondary;
    _transactionLog = TransactionLog();
    await _transactionLog.initialize();
    _initialized = true;

    if (_secondary != null) {
      _startHealthChecks();
      _startReplayTimer();
    }

    debugLog('SupabaseManager initialized (secondary: ${_secondary != null})');
  }

  /// Test-only initializer that accepts a pre-built TransactionLog.
  @visibleForTesting
  void initializeForTest({
    required SupabaseClient primary,
    SupabaseClient? secondary,
    required TransactionLog transactionLog,
  }) {
    _primary = primary;
    _secondary = secondary;
    _transactionLog = transactionLog;
    _initialized = true;
    _primaryHealthy = true;
    _secondaryHealthy = true;
  }

  /// Get a [SupabaseQueryBuilder] for reads. Prefers primary; falls back to
  /// secondary when primary is unhealthy.
  SupabaseQueryBuilder from(String table) {
    if (_primaryHealthy) {
      return _primary.from(table);
    } else if (_secondary != null && _secondaryHealthy) {
      debugLog(
        'SupabaseManager: reading "$table" from secondary (primary down)',
      );
      return _secondary!.from(table);
    }
    // Both down — try primary anyway, let it throw.
    return _primary.from(table);
  }

  /// Execute an RPC call. Reads go to healthy instance.
  Future<dynamic> rpc(String fn, {Map<String, dynamic>? params}) async {
    if (_primaryHealthy) {
      return _primary.rpc(fn, params: params ?? {});
    } else if (_secondary != null && _secondaryHealthy) {
      debugLog('SupabaseManager: rpc "$fn" on secondary (primary down)');
      return _secondary!.rpc(fn, params: params ?? {});
    }
    return _primary.rpc(fn, params: params ?? {});
  }

  /// Invoke an edge function. Tries primary first, falls back to secondary.
  Future<FunctionResponse> functionInvoke(
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      if (_primaryHealthy) {
        return await _primary.functions.invoke(
          functionName,
          body: body,
          headers: headers,
        );
      }
    } catch (e) {
      debugLogError(
        'SupabaseManager: primary function "$functionName" failed',
        e,
      );
      // Don't mark primary unhealthy for edge function failures.
      // Edge functions run on a separate service and their availability
      // does not indicate the database is down.
      rethrow;
    }

    if (_secondary != null && _secondaryHealthy) {
      debugLog('SupabaseManager: invoking "$functionName" on secondary');
      return _secondary!.functions.invoke(
        functionName,
        body: body,
        headers: headers,
      );
    }

    // Both down — rethrow from primary attempt.
    return _primary.functions.invoke(
      functionName,
      body: body,
      headers: headers,
    );
  }

  // ─── Dual-write methods ─────────────────────────────────────────────

  /// Insert into both instances. Queues failures for replay.
  Future<List<dynamic>> dualInsert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final primaryResult = await _writeTo(
      target: 'primary',
      client: _primary,
      table: table,
      operation: 'insert',
      data: data,
    );

    if (_secondary != null) {
      await _writeTo(
        target: 'secondary',
        client: _secondary!,
        table: table,
        operation: 'insert',
        data: data,
      );
    }

    return primaryResult ?? [];
  }

  /// Update on both instances. [filters] is a map of column→value for .eq().
  Future<void> dualUpdate(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> filters,
  }) async {
    await _writeTo(
      target: 'primary',
      client: _primary,
      table: table,
      operation: 'update',
      data: data,
      filters: filters,
    );

    if (_secondary != null) {
      await _writeTo(
        target: 'secondary',
        client: _secondary!,
        table: table,
        operation: 'update',
        data: data,
        filters: filters,
      );
    }
  }

  /// Delete from both instances. [filters] is a map of column→value for .eq().
  Future<void> dualDelete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    await _writeTo(
      target: 'primary',
      client: _primary,
      table: table,
      operation: 'delete',
      data: {},
      filters: filters,
    );

    if (_secondary != null) {
      await _writeTo(
        target: 'secondary',
        client: _secondary!,
        table: table,
        operation: 'delete',
        data: {},
        filters: filters,
      );
    }
  }

  /// Delete from both instances using inFilter (for batch deletes by ID list).
  Future<void> dualDeleteIn(
    String table, {
    required String column,
    required List<dynamic> values,
  }) async {
    if (values.isEmpty) return;

    final data = {'_inFilter_column': column, '_inFilter_values': values};

    await _writeTo(
      target: 'primary',
      client: _primary,
      table: table,
      operation: 'delete_in',
      data: data,
    );

    if (_secondary != null) {
      await _writeTo(
        target: 'secondary',
        client: _secondary!,
        table: table,
        operation: 'delete_in',
        data: data,
      );
    }
  }

  /// Upsert on both instances.
  Future<void> dualUpsert(
    String table,
    Map<String, dynamic> data, {
    String? onConflict,
  }) async {
    await _writeTo(
      target: 'primary',
      client: _primary,
      table: table,
      operation: 'upsert',
      data: {...data, if (onConflict != null) '_onConflict': onConflict},
    );

    if (_secondary != null) {
      await _writeTo(
        target: 'secondary',
        client: _secondary!,
        table: table,
        operation: 'upsert',
        data: {...data, if (onConflict != null) '_onConflict': onConflict},
      );
    }
  }

  /// Execute an RPC on both instances (for RPCs that mutate data).
  Future<dynamic> dualRpc(String fn, {Map<String, dynamic>? params}) async {
    dynamic result;

    try {
      result = await _primary.rpc(fn, params: params ?? {});
    } catch (e) {
      debugLogError('SupabaseManager: primary rpc "$fn" failed', e);
      _markPrimaryUnhealthy();
      _queueTransaction('primary', fn, 'rpc', params ?? {});
    }

    if (_secondary != null) {
      try {
        await _secondary!.rpc(fn, params: params ?? {});
      } catch (e) {
        debugLogError('SupabaseManager: secondary rpc "$fn" failed', e);
        _markSecondaryUnhealthy();
        _queueTransaction('secondary', fn, 'rpc', params ?? {});
      }
    }

    return result;
  }

  // ─── Internal helpers ───────────────────────────────────────────────

  Future<List<dynamic>?> _writeTo({
    required String target,
    required SupabaseClient client,
    required String table,
    required String operation,
    required Map<String, dynamic> data,
    Map<String, dynamic>? filters,
  }) async {
    final isHealthy = target == 'primary' ? _primaryHealthy : _secondaryHealthy;

    // If we already know this target is down, queue immediately.
    if (!isHealthy) {
      _queueTransaction(target, table, operation, data, filters: filters);
      return null;
    }

    try {
      switch (operation) {
        case 'insert':
          final result = await client.from(table).insert(data).select();
          return result;
        case 'update':
          var query = client.from(table).update(data);
          if (filters != null) {
            for (final entry in filters.entries) {
              query = query.eq(entry.key, entry.value);
            }
          }
          await query;
          return null;
        case 'delete':
          var query = client.from(table).delete();
          if (filters != null) {
            for (final entry in filters.entries) {
              query = query.eq(entry.key, entry.value);
            }
          }
          await query;
          return null;
        case 'delete_in':
          final col = data['_inFilter_column'] as String;
          final vals = data['_inFilter_values'] as List<dynamic>;
          await client.from(table).delete().inFilter(col, vals);
          return null;
        case 'upsert':
          final onConflict = data.remove('_onConflict') as String?;
          if (onConflict != null) {
            await client.from(table).upsert(data, onConflict: onConflict);
          } else {
            await client.from(table).upsert(data);
          }
          return null;
        default:
          debugLogError('SupabaseManager: unknown operation "$operation"');
          return null;
      }
    } catch (e) {
      debugLogError(
        'SupabaseManager: $target $operation on "$table" failed',
        e,
      );
      if (target == 'primary') {
        _markPrimaryUnhealthy();
      } else {
        _markSecondaryUnhealthy();
      }
      _queueTransaction(target, table, operation, data, filters: filters);
      return null;
    }
  }

  void _queueTransaction(
    String target,
    String table,
    String operation,
    Map<String, dynamic> data, {
    Map<String, dynamic>? filters,
  }) {
    if (!_initialized) return;

    final txn = PendingTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      target: target,
      table: table,
      operation: operation,
      data: Map<String, dynamic>.from(data),
      filters: filters != null ? Map<String, dynamic>.from(filters) : null,
      createdAt: DateTime.now().toUtc(),
    );
    _transactionLog.add(txn);
    debugLog(
      'SupabaseManager: queued $operation on "$table" for $target replay',
    );
  }

  // ─── Health checks ──────────────────────────────────────────────────

  void _startHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performHealthChecks(),
    );
  }

  void _startReplayTimer() {
    _replayTimer?.cancel();
    _replayTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _replayPendingTransactions(),
    );
  }

  Future<void> _performHealthChecks() async {
    // Check primary
    try {
      await _primary
          .from('crewtypes')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      if (!_primaryHealthy) {
        debugLog('SupabaseManager: primary recovered');
      }
      _primaryHealthy = true;
    } catch (_) {
      if (_primaryHealthy) {
        debugLog('SupabaseManager: primary is DOWN');
      }
      _primaryHealthy = false;
    }

    // Check secondary
    if (_secondary != null) {
      try {
        await _secondary!
            .from('crewtypes')
            .select('id')
            .limit(1)
            .timeout(const Duration(seconds: 5));
        if (!_secondaryHealthy) {
          debugLog('SupabaseManager: secondary recovered');
        }
        _secondaryHealthy = true;
      } catch (_) {
        if (_secondaryHealthy) {
          debugLog('SupabaseManager: secondary is DOWN');
        }
        _secondaryHealthy = false;
      }
    }

    _updateHealthStatus();
  }

  void _markPrimaryUnhealthy() {
    _primaryHealthy = false;
    _updateHealthStatus();
  }

  void _markSecondaryUnhealthy() {
    _secondaryHealthy = false;
    _updateHealthStatus();
  }

  void _updateHealthStatus() {
    if (_primaryHealthy && _secondaryHealthy) {
      healthStatus.value = HealthStatus.allHealthy;
    } else if (!_primaryHealthy && !_secondaryHealthy) {
      healthStatus.value = HealthStatus.allDown;
    } else {
      healthStatus.value = HealthStatus.degraded;
    }
  }

  // ─── Replay ─────────────────────────────────────────────────────────

  Future<void> _replayPendingTransactions() async {
    final pending = _transactionLog.getAll();
    if (pending.isEmpty) return;

    debugLog(
      'SupabaseManager: replaying ${pending.length} pending transactions',
    );

    for (final txn in List.of(pending)) {
      final targetClient = txn.target == 'primary' ? _primary : _secondary;
      final isHealthy = txn.target == 'primary'
          ? _primaryHealthy
          : _secondaryHealthy;

      if (targetClient == null || !isHealthy) continue;

      try {
        await _executeTransaction(targetClient, txn);
        _transactionLog.remove(txn.id);
        debugLog(
          'SupabaseManager: replayed ${txn.operation} on "${txn.table}" to ${txn.target}',
        );
      } catch (e) {
        txn.retryCount++;
        if (txn.retryCount >= 10) {
          debugLogError(
            'SupabaseManager: permanently failed ${txn.operation} on "${txn.table}"',
            e,
          );
          _transactionLog.remove(txn.id);
        } else {
          _transactionLog.update(txn);
          debugLog(
            'SupabaseManager: replay failed (attempt ${txn.retryCount}) for ${txn.table}',
          );
        }
      }
    }
  }

  Future<void> _executeTransaction(
    SupabaseClient client,
    PendingTransaction txn,
  ) async {
    switch (txn.operation) {
      case 'insert':
        await client.from(txn.table).insert(txn.data);
        break;
      case 'update':
        var query = client.from(txn.table).update(txn.data);
        if (txn.filters != null) {
          for (final entry in txn.filters!.entries) {
            query = query.eq(entry.key, entry.value);
          }
        }
        await query;
        break;
      case 'delete':
        var query = client.from(txn.table).delete();
        if (txn.filters != null) {
          for (final entry in txn.filters!.entries) {
            query = query.eq(entry.key, entry.value);
          }
        }
        await query;
        break;
      case 'delete_in':
        final col = txn.data['_inFilter_column'] as String;
        final vals = txn.data['_inFilter_values'] as List<dynamic>;
        await client.from(txn.table).delete().inFilter(col, vals);
        break;
      case 'upsert':
        final data = Map<String, dynamic>.from(txn.data);
        final onConflict = data.remove('_onConflict') as String?;
        if (onConflict != null) {
          await client.from(txn.table).upsert(data, onConflict: onConflict);
        } else {
          await client.from(txn.table).upsert(data);
        }
        break;
      case 'rpc':
        await client.rpc(txn.table, params: txn.data);
        break;
    }
  }

  /// Force a health check and replay cycle (useful for testing).
  Future<void> forceHealthCheckAndReplay() async {
    await _performHealthChecks();
    await _replayPendingTransactions();
  }

  /// Get the count of pending transactions.
  int get pendingTransactionCount => _transactionLog.getAll().length;

  void dispose() {
    _healthCheckTimer?.cancel();
    _replayTimer?.cancel();
  }
}

enum HealthStatus { allHealthy, degraded, allDown }
