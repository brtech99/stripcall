import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:stripcall/models/pending_transaction.dart';

void main() {
  group('PendingTransaction', () {
    late PendingTransaction txn;

    setUp(() {
      txn = PendingTransaction(
        id: '123456',
        target: 'primary',
        table: 'problem',
        operation: 'insert',
        data: {'strip': '1', 'crew': 3},
        filters: {'id': 42},
        createdAt: DateTime.utc(2026, 3, 10, 12, 0, 0),
        retryCount: 2,
      );
    });

    test('constructor sets all fields', () {
      expect(txn.id, '123456');
      expect(txn.target, 'primary');
      expect(txn.table, 'problem');
      expect(txn.operation, 'insert');
      expect(txn.data, {'strip': '1', 'crew': 3});
      expect(txn.filters, {'id': 42});
      expect(txn.createdAt, DateTime.utc(2026, 3, 10, 12, 0, 0));
      expect(txn.retryCount, 2);
    });

    test('retryCount defaults to 0', () {
      final t = PendingTransaction(
        id: '1',
        target: 'secondary',
        table: 'messages',
        operation: 'delete',
        data: {},
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(t.retryCount, 0);
    });

    test('filters defaults to null', () {
      final t = PendingTransaction(
        id: '1',
        target: 'primary',
        table: 'messages',
        operation: 'insert',
        data: {'msg': 'hello'},
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(t.filters, isNull);
    });

    group('toJson', () {
      test('serializes all fields', () {
        final json = txn.toJson();
        expect(json['id'], '123456');
        expect(json['target'], 'primary');
        expect(json['table'], 'problem');
        expect(json['operation'], 'insert');
        expect(json['data'], {'strip': '1', 'crew': 3});
        expect(json['filters'], {'id': 42});
        expect(json['createdAt'], '2026-03-10T12:00:00.000Z');
        expect(json['retryCount'], 2);
      });

      test('serializes null filters', () {
        final t = PendingTransaction(
          id: '1',
          target: 'primary',
          table: 'x',
          operation: 'insert',
          data: {},
          createdAt: DateTime.utc(2026, 1, 1),
        );
        expect(t.toJson()['filters'], isNull);
      });
    });

    group('fromJson', () {
      test('deserializes all fields', () {
        final json = txn.toJson();
        final restored = PendingTransaction.fromJson(json);
        expect(restored.id, txn.id);
        expect(restored.target, txn.target);
        expect(restored.table, txn.table);
        expect(restored.operation, txn.operation);
        expect(restored.data, txn.data);
        expect(restored.filters, txn.filters);
        expect(restored.createdAt, txn.createdAt);
        expect(restored.retryCount, txn.retryCount);
      });

      test('handles missing retryCount', () {
        final json = txn.toJson();
        json.remove('retryCount');
        final restored = PendingTransaction.fromJson(json);
        expect(restored.retryCount, 0);
      });

      test('handles null filters', () {
        final json = txn.toJson();
        json['filters'] = null;
        final restored = PendingTransaction.fromJson(json);
        expect(restored.filters, isNull);
      });
    });

    group('serialize / deserialize', () {
      test('roundtrip preserves all data', () {
        final serialized = txn.serialize();
        final restored = PendingTransaction.deserialize(serialized);
        expect(restored.id, txn.id);
        expect(restored.target, txn.target);
        expect(restored.table, txn.table);
        expect(restored.operation, txn.operation);
        expect(restored.data, txn.data);
        expect(restored.filters, txn.filters);
        expect(restored.createdAt, txn.createdAt);
        expect(restored.retryCount, txn.retryCount);
      });

      test('serialize produces valid JSON string', () {
        final serialized = txn.serialize();
        final decoded = jsonDecode(serialized);
        expect(decoded, isA<Map<String, dynamic>>());
      });

      test('deserialize throws on invalid JSON', () {
        expect(
          () => PendingTransaction.deserialize('not json'),
          throwsA(isA<FormatException>()),
        );
      });
    });

    test('retryCount is mutable', () {
      txn.retryCount++;
      expect(txn.retryCount, 3);
      txn.retryCount = 0;
      expect(txn.retryCount, 0);
    });
  });
}
