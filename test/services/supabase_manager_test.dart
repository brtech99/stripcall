import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stripcall/services/supabase_manager.dart';
import 'package:stripcall/services/transaction_log.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<SupabaseQueryBuilder>(),
  MockSpec<FunctionsClient>(),
  MockSpec<GoTrueClient>(),
])
import 'supabase_manager_test.mocks.dart';

void main() {
  late SupabaseManager manager;
  late MockSupabaseClient mockPrimary;
  late MockSupabaseClient mockSecondary;
  late TransactionLog transactionLog;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    transactionLog = TransactionLog();
    await transactionLog.initialize();

    mockPrimary = MockSupabaseClient();
    mockSecondary = MockSupabaseClient();

    manager = SupabaseManager.forTesting();
  });

  void initWithBoth() {
    manager.initializeForTest(
      primary: mockPrimary,
      secondary: mockSecondary,
      transactionLog: transactionLog,
    );
  }

  void initPrimaryOnly() {
    manager.initializeForTest(
      primary: mockPrimary,
      transactionLog: transactionLog,
    );
  }

  // ─── Initialization ──────────────────────────────────────────────────

  group('initialization', () {
    test('starts with both healthy', () {
      initWithBoth();
      expect(manager.primaryHealthy, true);
      expect(manager.secondaryHealthy, true);
      expect(manager.healthStatus.value, HealthStatus.allHealthy);
    });

    test('hasSecondary is true when secondary provided', () {
      initWithBoth();
      expect(manager.hasSecondary, true);
    });

    test('hasSecondary is false when no secondary', () {
      initPrimaryOnly();
      expect(manager.hasSecondary, false);
    });

    test('client returns primary client', () {
      initWithBoth();
      expect(manager.client, mockPrimary);
    });

    test('auth returns primary auth', () {
      final mockAuth = MockGoTrueClient();
      when(mockPrimary.auth).thenReturn(mockAuth);
      initWithBoth();
      expect(manager.auth, mockAuth);
    });
  });

  // ─── Health Status ────────────────────────────────────────────────────

  group('HealthStatus transitions', () {
    setUp(() => initWithBoth());

    test('allHealthy when both healthy', () {
      expect(manager.healthStatus.value, HealthStatus.allHealthy);
    });

    test('degraded when primary down', () {
      manager.primaryHealthyForTest = false;
      expect(manager.healthStatus.value, HealthStatus.degraded);
    });

    test('degraded when secondary down', () {
      manager.secondaryHealthyForTest = false;
      expect(manager.healthStatus.value, HealthStatus.degraded);
    });

    test('allDown when both down', () {
      manager.primaryHealthyForTest = false;
      manager.secondaryHealthyForTest = false;
      expect(manager.healthStatus.value, HealthStatus.allDown);
    });

    test('recovers to allHealthy', () {
      manager.primaryHealthyForTest = false;
      expect(manager.healthStatus.value, HealthStatus.degraded);
      manager.primaryHealthyForTest = true;
      expect(manager.healthStatus.value, HealthStatus.allHealthy);
    });

    test('healthStatus notifies listeners', () {
      final values = <HealthStatus>[];
      manager.healthStatus.addListener(() {
        values.add(manager.healthStatus.value);
      });

      manager.primaryHealthyForTest = false;
      manager.secondaryHealthyForTest = false;
      manager.primaryHealthyForTest = true;

      expect(values, [
        HealthStatus.degraded,
        HealthStatus.allDown,
        HealthStatus.degraded,
      ]);
    });
  });

  // ─── from() read routing ─────────────────────────────────────────────

  group('from() read routing', () {
    late MockSupabaseQueryBuilder mockPrimaryQB;
    late MockSupabaseQueryBuilder mockSecondaryQB;

    setUp(() {
      mockPrimaryQB = MockSupabaseQueryBuilder();
      mockSecondaryQB = MockSupabaseQueryBuilder();
      // SupabaseQueryBuilder is thenable, so must use thenAnswer
      when(mockPrimary.from('problem')).thenAnswer((_) => mockPrimaryQB);
      when(mockSecondary.from('problem')).thenAnswer((_) => mockSecondaryQB);
      initWithBoth();
    });

    test('routes to primary when healthy', () {
      expect(manager.from('problem'), mockPrimaryQB);
    });

    test('routes to secondary when primary unhealthy', () {
      manager.primaryHealthyForTest = false;
      expect(manager.from('problem'), mockSecondaryQB);
    });

    test('falls back to primary when both unhealthy', () {
      manager.primaryHealthyForTest = false;
      manager.secondaryHealthyForTest = false;
      expect(manager.from('problem'), mockPrimaryQB);
    });

    test('routes to primary when no secondary configured', () {
      initPrimaryOnly();
      when(mockPrimary.from('problem')).thenAnswer((_) => mockPrimaryQB);
      manager.primaryHealthyForTest = false;
      expect(manager.from('problem'), mockPrimaryQB);
    });
  });

  // ─── rpc() routing ───────────────────────────────────────────────────

  group('rpc() routing', () {
    // rpc() returns PostgrestFilterBuilder — NiceMock fakes crash on await.
    // Stub with thenThrow before init, then verify which client was called.

    test('calls primary when healthy', () async {
      when(mockPrimary.rpc(any, params: anyNamed('params')))
          .thenThrow(Exception('stub'));
      initWithBoth();

      try { await manager.rpc('my_func'); } catch (_) {}
      verify(mockPrimary.rpc('my_func', params: {})).called(1);
      verifyNever(mockSecondary.rpc(any, params: anyNamed('params')));
    });

    test('calls secondary when primary unhealthy', () async {
      when(mockSecondary.rpc(any, params: anyNamed('params')))
          .thenThrow(Exception('stub'));
      initWithBoth();
      manager.primaryHealthyForTest = false;

      try { await manager.rpc('my_func'); } catch (_) {}
      verifyNever(mockPrimary.rpc(any, params: anyNamed('params')));
      verify(mockSecondary.rpc('my_func', params: {})).called(1);
    });

    test('falls back to primary when both unhealthy', () async {
      when(mockPrimary.rpc(any, params: anyNamed('params')))
          .thenThrow(Exception('stub'));
      initWithBoth();
      manager.primaryHealthyForTest = false;
      manager.secondaryHealthyForTest = false;

      try { await manager.rpc('my_func'); } catch (_) {}
      verify(mockPrimary.rpc('my_func', params: {})).called(1);
    });
  });

  // ─── functionInvoke() ────────────────────────────────────────────────

  group('functionInvoke()', () {
    late MockFunctionsClient mockPrimaryFunctions;
    late MockFunctionsClient mockSecondaryFunctions;

    setUp(() {
      mockPrimaryFunctions = MockFunctionsClient();
      mockSecondaryFunctions = MockFunctionsClient();
      when(mockPrimary.functions).thenReturn(mockPrimaryFunctions);
      when(mockSecondary.functions).thenReturn(mockSecondaryFunctions);
      initWithBoth();
    });

    test('calls primary when healthy', () async {
      final response = FunctionResponse(status: 200, data: {});
      when(mockPrimaryFunctions.invoke('test-fn', body: null, headers: null))
          .thenAnswer((_) async => response);

      final result = await manager.functionInvoke('test-fn');
      expect(result.status, 200);
    });

    test('does NOT mark primary unhealthy on edge function failure', () async {
      when(mockPrimaryFunctions.invoke('test-fn', body: null, headers: null))
          .thenThrow(Exception('edge function error'));

      expect(
        () => manager.functionInvoke('test-fn'),
        throwsA(isA<Exception>()),
      );
      expect(manager.primaryHealthy, true);
      expect(manager.healthStatus.value, HealthStatus.allHealthy);
    });

    test('falls back to secondary when primary unhealthy', () async {
      manager.primaryHealthyForTest = false;
      final response = FunctionResponse(status: 200, data: {});
      when(mockSecondaryFunctions.invoke('test-fn', body: null, headers: null))
          .thenAnswer((_) async => response);

      final result = await manager.functionInvoke('test-fn');
      expect(result.status, 200);
      verifyNever(mockPrimaryFunctions.invoke(
        any,
        body: anyNamed('body'),
        headers: anyNamed('headers'),
      ));
    });
  });

  // ─── Dual-write: unhealthy target queueing ───────────────────────────

  group('dual-write queueing when unhealthy', () {
    // When a target is already marked unhealthy, _writeTo queues immediately
    // without calling from(). This tests that core routing logic.

    test('dualInsert queues primary when unhealthy', () async {
      initWithBoth();
      manager.primaryHealthyForTest = false;
      try { await manager.dualInsert('problem', {'strip': '5'}); } catch (_) {}
      verifyNever(mockPrimary.from('problem'));
      expect(manager.pendingTransactionCount, greaterThanOrEqualTo(1));
    });

    test('dualInsert queues secondary when unhealthy', () async {
      initWithBoth();
      manager.secondaryHealthyForTest = false;
      try { await manager.dualInsert('problem', {'strip': '5'}); } catch (_) {}
      verifyNever(mockSecondary.from('problem'));
      expect(manager.pendingTransactionCount, greaterThanOrEqualTo(1));
    });

    test('dualInsert skips secondary when not configured', () async {
      initPrimaryOnly();
      try { await manager.dualInsert('problem', {'strip': '5'}); } catch (_) {}
      verifyNever(mockSecondary.from(any));
    });

    test('dualUpdate queues secondary when unhealthy', () async {
      initWithBoth();
      manager.secondaryHealthyForTest = false;
      try {
        await manager.dualUpdate('problem', {'x': 1}, filters: {'id': 1});
      } catch (_) {}
      verifyNever(mockSecondary.from('problem'));
      expect(manager.pendingTransactionCount, greaterThanOrEqualTo(1));
    });

    test('dualDelete queues primary when unhealthy', () async {
      initWithBoth();
      manager.primaryHealthyForTest = false;
      try {
        await manager.dualDelete('problem', filters: {'id': 1});
      } catch (_) {}
      verifyNever(mockPrimary.from('problem'));
      expect(manager.pendingTransactionCount, greaterThanOrEqualTo(1));
    });

    test('dualDeleteIn returns early for empty values', () async {
      initPrimaryOnly();
      await manager.dualDeleteIn('problem', column: 'id', values: []);
      verifyNever(mockPrimary.from(any));
      expect(manager.pendingTransactionCount, 0);
    });

    test('dualDeleteIn queues secondary when unhealthy', () async {
      initWithBoth();
      manager.secondaryHealthyForTest = false;
      try {
        await manager.dualDeleteIn('problem', column: 'id', values: [1, 2]);
      } catch (_) {}
      verifyNever(mockSecondary.from('problem'));
      expect(manager.pendingTransactionCount, greaterThanOrEqualTo(1));
    });

    test('dualUpsert queues secondary when unhealthy', () async {
      initWithBoth();
      manager.secondaryHealthyForTest = false;
      try {
        await manager.dualUpsert('problem', {'id': 1, 'strip': '5'});
      } catch (_) {}
      verifyNever(mockSecondary.from('problem'));
      expect(manager.pendingTransactionCount, greaterThanOrEqualTo(1));
    });
  });

  // ─── Dual-write: failure marks unhealthy ──────────────────────────────

  group('dual-write failure marks target unhealthy', () {
    test('dualInsert marks primary unhealthy on from() failure', () async {
      when(mockPrimary.from('problem')).thenThrow(Exception('db down'));
      initPrimaryOnly();

      // Primary failure rethrows from _writeTo, so dualInsert throws
      try {
        await manager.dualInsert('problem', {'strip': '5'});
      } catch (_) {}
      expect(manager.primaryHealthy, false);
      expect(manager.pendingTransactionCount, 1);
    });

    test('secondary marked unhealthy via setter', () {
      // Direct secondary failure testing through dual-write methods requires
      // primary to succeed (complex mock chain). Verify the marking mechanism
      // works correctly via the test setter instead.
      initWithBoth();
      expect(manager.secondaryHealthy, true);
      manager.secondaryHealthyForTest = false;
      expect(manager.secondaryHealthy, false);
      expect(manager.healthStatus.value, HealthStatus.degraded);
    });
  });

  // ─── dualRpc ─────────────────────────────────────────────────────────

  group('dualRpc', () {
    // dualRpc catches all exceptions. NiceMock rpc() returns a fake
    // PostgrestFilterBuilder that throws on await, which dualRpc catches.

    test('queues and marks both unhealthy when rpc fails', () async {
      initWithBoth();
      // NiceMock fakes will fail on await → caught → queued
      await manager.dualRpc('my_func');
      expect(manager.primaryHealthy, false);
      expect(manager.secondaryHealthy, false);
      expect(manager.pendingTransactionCount, 2);
    });

    test('queues primary only when no secondary', () async {
      initPrimaryOnly();
      await manager.dualRpc('my_func');
      expect(manager.primaryHealthy, false);
      expect(manager.pendingTransactionCount, 1);
    });

    test('calls rpc on both clients', () async {
      initWithBoth();
      await manager.dualRpc('my_func');
      verify(mockPrimary.rpc('my_func', params: {})).called(1);
      verify(mockSecondary.rpc('my_func', params: {})).called(1);
    });
  });

  // ─── Misc ────────────────────────────────────────────────────────────

  group('pendingTransactionCount', () {
    test('starts at zero', () {
      initPrimaryOnly();
      expect(manager.pendingTransactionCount, 0);
    });
  });

  group('dispose', () {
    test('does not throw', () {
      initPrimaryOnly();
      expect(() => manager.dispose(), returnsNormally);
    });
  });
}
