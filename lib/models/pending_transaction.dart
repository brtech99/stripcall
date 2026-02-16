import 'dart:convert';

/// Represents a failed write that needs to be replayed against a Supabase
/// instance once it recovers.
class PendingTransaction {
  final String id;
  final String target; // 'primary' or 'secondary'
  final String table;
  final String operation; // 'insert', 'update', 'delete', 'upsert', 'rpc'
  final Map<String, dynamic> data;
  final Map<String, dynamic>? filters;
  final DateTime createdAt;
  int retryCount;

  PendingTransaction({
    required this.id,
    required this.target,
    required this.table,
    required this.operation,
    required this.data,
    this.filters,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'target': target,
    'table': table,
    'operation': operation,
    'data': data,
    'filters': filters,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory PendingTransaction.fromJson(Map<String, dynamic> json) {
    return PendingTransaction(
      id: json['id'] as String,
      target: json['target'] as String,
      table: json['table'] as String,
      operation: json['operation'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      filters: json['filters'] != null
          ? Map<String, dynamic>.from(json['filters'] as Map)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  /// Serialize to a string for storage in SharedPreferences.
  String serialize() => jsonEncode(toJson());

  /// Deserialize from a string stored in SharedPreferences.
  factory PendingTransaction.deserialize(String s) =>
      PendingTransaction.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
