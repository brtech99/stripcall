import 'package:shared_preferences/shared_preferences.dart';
import '../models/pending_transaction.dart';
import '../utils/debug_utils.dart';

/// Persists pending dual-write transactions using SharedPreferences.
///
/// Transactions that failed against one Supabase instance are stored here
/// and replayed by [SupabaseManager] when that instance recovers.
class TransactionLog {
  static const _storageKey = 'pending_transactions';

  List<PendingTransaction> _cache = [];
  late SharedPreferences _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromDisk();
  }

  void _loadFromDisk() {
    final stored = _prefs.getStringList(_storageKey) ?? [];
    _cache = stored
        .map((s) {
          try {
            return PendingTransaction.deserialize(s);
          } catch (e) {
            debugLogError('TransactionLog: failed to deserialize entry', e);
            return null;
          }
        })
        .whereType<PendingTransaction>()
        .toList();

    if (_cache.isNotEmpty) {
      debugLog('TransactionLog: loaded ${_cache.length} pending transactions');
    }
  }

  Future<void> _saveToDisk() async {
    final serialized = _cache.map((t) => t.serialize()).toList();
    await _prefs.setStringList(_storageKey, serialized);
  }

  void add(PendingTransaction txn) {
    _cache.add(txn);
    _saveToDisk();
  }

  void remove(String id) {
    _cache.removeWhere((t) => t.id == id);
    _saveToDisk();
  }

  void update(PendingTransaction txn) {
    final index = _cache.indexWhere((t) => t.id == txn.id);
    if (index >= 0) {
      _cache[index] = txn;
      _saveToDisk();
    }
  }

  List<PendingTransaction> getAll() => List.unmodifiable(_cache);

  Future<void> clear() async {
    _cache.clear();
    await _prefs.remove(_storageKey);
  }
}
