import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stripcall/models/pending_transaction.dart';
import 'package:stripcall/services/transaction_log.dart';

void main() {
  group('TransactionLog', () {
    late TransactionLog log;

    PendingTransaction _makeTxn({
      String id = '1',
      String target = 'primary',
      String table = 'problem',
      String operation = 'insert',
    }) {
      return PendingTransaction(
        id: id,
        target: target,
        table: table,
        operation: operation,
        data: {'strip': '5'},
        createdAt: DateTime.utc(2026, 3, 10, 12),
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      log = TransactionLog();
      await log.initialize();
    });

    test('starts empty', () {
      expect(log.getAll(), isEmpty);
    });

    test('add stores transaction', () {
      log.add(_makeTxn(id: '1'));
      expect(log.getAll().length, 1);
      expect(log.getAll()[0].id, '1');
    });

    test('add multiple transactions', () {
      log.add(_makeTxn(id: '1'));
      log.add(_makeTxn(id: '2'));
      log.add(_makeTxn(id: '3'));
      expect(log.getAll().length, 3);
    });

    test('remove by id', () {
      log.add(_makeTxn(id: '1'));
      log.add(_makeTxn(id: '2'));
      log.remove('1');
      expect(log.getAll().length, 1);
      expect(log.getAll()[0].id, '2');
    });

    test('remove non-existent id is no-op', () {
      log.add(_makeTxn(id: '1'));
      log.remove('999');
      expect(log.getAll().length, 1);
    });

    test('update replaces existing transaction', () {
      final txn = _makeTxn(id: '1');
      log.add(txn);

      final updated = PendingTransaction(
        id: '1',
        target: 'secondary',
        table: 'messages',
        operation: 'update',
        data: {'msg': 'updated'},
        createdAt: DateTime.utc(2026, 3, 10, 12),
        retryCount: 3,
      );
      log.update(updated);

      expect(log.getAll().length, 1);
      expect(log.getAll()[0].target, 'secondary');
      expect(log.getAll()[0].retryCount, 3);
    });

    test('update non-existent id is no-op', () {
      log.add(_makeTxn(id: '1'));
      final updated = _makeTxn(id: '999');
      log.update(updated);
      expect(log.getAll().length, 1);
      expect(log.getAll()[0].id, '1');
    });

    test('clear removes all transactions', () async {
      log.add(_makeTxn(id: '1'));
      log.add(_makeTxn(id: '2'));
      await log.clear();
      expect(log.getAll(), isEmpty);
    });

    test('getAll returns unmodifiable list', () {
      log.add(_makeTxn(id: '1'));
      final list = log.getAll();
      expect(() => list.add(_makeTxn(id: '2')), throwsA(isA<UnsupportedError>()));
    });

    test('persists across instances', () async {
      log.add(_makeTxn(id: '1'));
      log.add(_makeTxn(id: '2'));

      // Create a new TransactionLog instance with same SharedPreferences
      final log2 = TransactionLog();
      await log2.initialize();

      expect(log2.getAll().length, 2);
      expect(log2.getAll()[0].id, '1');
      expect(log2.getAll()[1].id, '2');
    });

    test('handles corrupted data on disk gracefully', () async {
      // Write bad data directly to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pending_transactions', [
        '{"id":"1","target":"primary","table":"x","operation":"insert","data":{},"createdAt":"2026-01-01T00:00:00.000Z"}',
        'not valid json',
        '{"id":"2","target":"primary","table":"y","operation":"update","data":{},"createdAt":"2026-01-01T00:00:00.000Z"}',
      ]);

      final log2 = TransactionLog();
      await log2.initialize();

      // Should have loaded 2 valid entries, skipping the bad one
      expect(log2.getAll().length, 2);
      expect(log2.getAll()[0].id, '1');
      expect(log2.getAll()[1].id, '2');
    });
  });
}
