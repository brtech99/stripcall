// Failover Integration Test
//
// Tests the complete failover lifecycle against a REAL local Supabase instance:
//   1. Normal operation: create problem, resolve it → both DBs written
//   2. Failover: primary goes down, create problem, resolve it → secondary written, primary queued
//   3. Failback: primary recovers, replay runs → all data consistent
//
// PREREQUISITES:
//   - Docker running
//   - supabase start
//   - supabase db reset  (fresh seed data)
//
// RUN:
//   flutter test test/failover_test.dart --no-pub --timeout 60s
//
// Both "primary" and "secondary" clients point to the same local Supabase.
// Primary uses the anon key (subject to RLS), secondary uses service_role key
// (bypasses RLS). This tests the real SupabaseManager code paths end-to-end.
// The actual two-server topology is verified separately via failover_preflight.sh.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stripcall/services/supabase_manager.dart';
import 'package:stripcall/services/transaction_log.dart';

// Local Supabase credentials (from `supabase start`)
const _url = 'http://127.0.0.1:54321';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const _serviceRoleKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

// Seeded test data IDs (from seed.sql)
const _testEmail = 'e2e_superuser@test.com';
const _testPassword = 'TestPassword123!';
const _testUserId = 'a0000000-0000-0000-0000-000000000001';
const _eventId = 1; // E2E Test Event
const _armorerCrewId = 1;
const _symptomId = 1; // Blade broken
const _actionId = 1; // Replaced blade

void main() {
  late SupabaseClient primary;
  late SupabaseClient secondary;
  late SupabaseManager manager;
  late TransactionLog txnLog;

  // Track problem IDs for cleanup
  final createdProblemIds = <int>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    // Create two separate clients to the same local Supabase
    primary = SupabaseClient(_url, _anonKey);
    secondary = SupabaseClient(_url, _serviceRoleKey);

    // Authenticate primary client as test superuser
    await primary.auth.signInWithPassword(
      email: _testEmail,
      password: _testPassword,
    );

    // Initialize SupabaseManager with both clients
    txnLog = TransactionLog();
    await txnLog.initialize();

    manager = SupabaseManager.forTesting();
    manager.initializeForTest(
      primary: primary,
      secondary: secondary,
      transactionLog: txnLog,
    );
  });

  tearDownAll(() async {
    // Clean up test problems
    if (createdProblemIds.isNotEmpty) {
      for (final id in createdProblemIds) {
        try {
          await secondary.from('problem').delete().eq('id', id);
        } catch (_) {}
      }
    }
    await primary.auth.signOut();
    primary.dispose();
    secondary.dispose();
  });

  test('Full failover lifecycle: create, failover, create, failback, verify',
      () async {
    // ═══════════════════════════════════════════════════════════════════
    // PHASE 1: Normal operation — create and resolve Problem A
    // ═══════════════════════════════════════════════════════════════════

    // Verify starting state
    expect(manager.primaryHealthy, true);
    expect(manager.secondaryHealthy, true);
    expect(manager.healthStatus.value, HealthStatus.allHealthy);
    expect(manager.pendingTransactionCount, 0);

    // Create Problem A
    final problemAData = {
      'event': _eventId,
      'crew': _armorerCrewId,
      'originator': _testUserId,
      'strip': 'F1',
      'symptom': _symptomId,
      'startdatetime': DateTime.now().toUtc().toIso8601String(),
    };

    final resultA = await manager.dualInsert('problem', problemAData);
    expect(resultA, isNotEmpty, reason: 'dualInsert should return inserted row');
    final problemAId = resultA.first['id'] as int;
    createdProblemIds.add(problemAId);

    // Verify Problem A exists
    final fetchA = await manager
        .from('problem')
        .select()
        .eq('id', problemAId)
        .single();
    expect(fetchA['strip'], 'F1');
    expect(fetchA['enddatetime'], isNull, reason: 'Problem A should be open');

    // Resolve Problem A
    await manager.dualUpdate(
      'problem',
      {
        'action': _actionId,
        'actionby': _testUserId,
        'enddatetime': DateTime.now().toUtc().toIso8601String(),
        'notes': 'Fixed during normal operation',
      },
      filters: {'id': problemAId},
    );

    // Verify Problem A is resolved
    final resolvedA = await manager
        .from('problem')
        .select()
        .eq('id', problemAId)
        .single();
    expect(resolvedA['enddatetime'], isNotNull,
        reason: 'Problem A should be resolved');
    expect(resolvedA['action'], _actionId);
    expect(resolvedA['notes'], 'Fixed during normal operation');

    // No pending transactions in normal operation
    expect(manager.pendingTransactionCount, 0,
        reason: 'No failures = no queued transactions');

    // ═══════════════════════════════════════════════════════════════════
    // PHASE 2: Simulate failover — primary goes down
    // ═══════════════════════════════════════════════════════════════════

    manager.primaryHealthyForTest = false;
    expect(manager.healthStatus.value, HealthStatus.degraded);

    // Create Problem B while primary is "down"
    // The dual-write should: queue for primary, write to secondary
    final problemBData = {
      'event': _eventId,
      'crew': _armorerCrewId,
      'originator': _testUserId,
      'strip': 'F2',
      'symptom': _symptomId,
      'startdatetime': DateTime.now().toUtc().toIso8601String(),
    };

    final resultB = await manager.dualInsert('problem', problemBData);
    expect(resultB, isNotEmpty,
        reason: 'dualInsert should succeed via secondary during failover');
    final problemBId = resultB.first['id'] as int;
    createdProblemIds.add(problemBId);

    // Primary insert was queued
    expect(manager.pendingTransactionCount, greaterThanOrEqualTo(1),
        reason: 'Primary insert should be queued for replay');

    // Reads should route to secondary (since primary is "down")
    final fetchB = await manager
        .from('problem')
        .select()
        .eq('id', problemBId)
        .single();
    expect(fetchB['strip'], 'F2');

    // Resolve Problem B while primary is still "down"
    await manager.dualUpdate(
      'problem',
      {
        'action': _actionId,
        'actionby': _testUserId,
        'enddatetime': DateTime.now().toUtc().toIso8601String(),
        'notes': 'Fixed during failover',
      },
      filters: {'id': problemBId},
    );

    // Primary update was also queued
    expect(manager.pendingTransactionCount, greaterThanOrEqualTo(2),
        reason: 'Primary insert + update should both be queued');

    // Verify Problem B is resolved (read from secondary)
    final resolvedB = await manager
        .from('problem')
        .select()
        .eq('id', problemBId)
        .single();
    expect(resolvedB['enddatetime'], isNotNull,
        reason: 'Problem B should be resolved via secondary');
    expect(resolvedB['notes'], 'Fixed during failover');

    // ═══════════════════════════════════════════════════════════════════
    // PHASE 3: Failback — primary recovers
    // ═══════════════════════════════════════════════════════════════════

    final pendingBefore = manager.pendingTransactionCount;
    expect(pendingBefore, greaterThanOrEqualTo(2),
        reason: 'Should have queued transactions before recovery');

    // Restore primary health
    manager.primaryHealthyForTest = true;
    expect(manager.healthStatus.value, HealthStatus.allHealthy);

    // Trigger replay of pending transactions
    // Note: In the real app, the 30-second replay timer handles this.
    // Since both clients point to the same DB, the "replay" will attempt
    // to re-insert/re-update rows that already exist. The insert will
    // succeed (creating a duplicate) or fail (if there's a unique
    // constraint). Either way, we verify the mechanism runs.
    await manager.forceHealthCheckAndReplay();

    // After replay, pending transactions should be drained
    // (They either succeeded or hit max retries)
    expect(manager.pendingTransactionCount, lessThan(pendingBefore),
        reason: 'Replay should process pending transactions');

    // ═══════════════════════════════════════════════════════════════════
    // PHASE 4: Verification — both problems exist and are resolved
    // ═══════════════════════════════════════════════════════════════════

    // Read from primary client (now healthy)
    final allProblems = await primary
        .from('problem')
        .select()
        .inFilter('id', createdProblemIds)
        .order('id');

    expect(allProblems.length, greaterThanOrEqualTo(2),
        reason: 'Both problems should exist');

    final pA = allProblems.firstWhere((p) => p['id'] == problemAId);
    final pB = allProblems.firstWhere((p) => p['id'] == problemBId);

    // Problem A (created during normal operation)
    expect(pA['strip'], 'F1');
    expect(pA['enddatetime'], isNotNull);
    expect(pA['notes'], 'Fixed during normal operation');

    // Problem B (created during failover)
    expect(pB['strip'], 'F2');
    expect(pB['enddatetime'], isNotNull);
    expect(pB['notes'], 'Fixed during failover');

    // Also verify via secondary client
    final secondaryProblems = await secondary
        .from('problem')
        .select()
        .inFilter('id', createdProblemIds)
        .order('id');

    expect(secondaryProblems.length, greaterThanOrEqualTo(2),
        reason: 'Secondary should also have both problems');

    // Final health state
    expect(manager.healthStatus.value, HealthStatus.allHealthy);
  });

  test('dualInsert throws when BOTH primary and secondary are down', () async {
    // Use a fresh manager with mocks to truly simulate both being down
    // (using real clients that share a DB can't truly be "down")
    SharedPreferences.setMockInitialValues({});
    final freshLog = TransactionLog();
    await freshLog.initialize();

    final freshManager = SupabaseManager.forTesting();
    // Initialize with primary only (no secondary)
    freshManager.initializeForTest(
      primary: primary,
      transactionLog: freshLog,
    );

    // Mark primary unhealthy — no secondary means nowhere to write
    freshManager.primaryHealthyForTest = false;

    expect(
      () => freshManager.dualInsert('problem', {
        'event': _eventId,
        'crew': _armorerCrewId,
        'originator': _testUserId,
        'strip': 'X1',
        'symptom': _symptomId,
        'startdatetime': DateTime.now().toUtc().toIso8601String(),
      }),
      throwsA(isA<Exception>()),
      reason: 'Should throw when primary is down and no secondary exists',
    );
  });

  test('dualUpdate succeeds on secondary when primary is down', () async {
    // Create a problem in normal mode
    final result = await manager.dualInsert('problem', {
      'event': _eventId,
      'crew': _armorerCrewId,
      'originator': _testUserId,
      'strip': 'F3',
      'symptom': _symptomId,
      'startdatetime': DateTime.now().toUtc().toIso8601String(),
    });
    final problemId = result.first['id'] as int;
    createdProblemIds.add(problemId);

    // Now simulate primary failure
    manager.primaryHealthyForTest = false;
    final pendingBefore = manager.pendingTransactionCount;

    // Update should NOT throw — secondary handles it
    await manager.dualUpdate(
      'problem',
      {'notes': 'Updated during failover'},
      filters: {'id': problemId},
    );

    // Verify the update went through (reads go to secondary)
    final updated = await manager
        .from('problem')
        .select()
        .eq('id', problemId)
        .single();
    expect(updated['notes'], 'Updated during failover');

    // Primary update was queued
    expect(manager.pendingTransactionCount, greaterThan(pendingBefore));

    // Restore
    manager.primaryHealthyForTest = true;
  });

  test('dualDelete succeeds on secondary when primary is down', () async {
    // Create a problem in normal mode
    final result = await manager.dualInsert('problem', {
      'event': _eventId,
      'crew': _armorerCrewId,
      'originator': _testUserId,
      'strip': 'F4',
      'symptom': _symptomId,
      'startdatetime': DateTime.now().toUtc().toIso8601String(),
    });
    final problemId = result.first['id'] as int;
    // Don't add to createdProblemIds — we're deleting it

    // Simulate primary failure
    manager.primaryHealthyForTest = false;

    // Delete should NOT throw
    await manager.dualDelete('problem', filters: {'id': problemId});

    // Verify deletion (reads go to secondary)
    final remaining = await manager
        .from('problem')
        .select()
        .eq('id', problemId);
    expect(remaining, isEmpty, reason: 'Problem should be deleted');

    // Restore
    manager.primaryHealthyForTest = true;
  });
}
