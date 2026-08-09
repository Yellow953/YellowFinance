import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../providers/firestore_provider.dart';

/// CRUD operations for user transactions.
class TransactionRepository {
  final FirestoreProvider _firestore;
  final _uuid = const Uuid();

  TransactionRepository({required FirestoreProvider firestore})
      : _firestore = firestore;

  /// Runs [query] against the server, falling back to the local cache.
  ///
  /// `Source.serverAndCache` already falls back on its own, but only once the
  /// SDK has concluded it is offline — which can outlast the timeout on a flaky
  /// connection. Catching the timeout and re-reading from cache means a slow or
  /// dead network degrades to cached data instead of an error.
  Future<QuerySnapshot<Map<String, dynamic>>> _getWithCacheFallback(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return await query
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      return query.get(const GetOptions(source: Source.cache));
    }
  }

  /// Streams all transactions for [uid] ordered by date descending.
  ///
  /// `includeMetadataChanges` so the stream re-emits when a write is
  /// acknowledged: `pendingSync` reads `hasPendingWrites`, and an ack changes
  /// only that metadata.
  Stream<List<TransactionModel>> watchTransactions(String uid) {
    return _firestore
        .transactionsCollection(uid)
        .orderBy('date', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) =>
            snap.docs.map(TransactionModel.fromFirestore).toList());
  }

  /// Fetches a page of transactions for [uid].
  ///
  /// Pass [startAfter] to get the next page (cursor-based pagination).
  /// Optionally filter by [startDate] and [endDate].
  Future<({List<TransactionModel> transactions, DocumentSnapshot? lastDoc})>
      fetchPage({
    required String uid,
    int limit = 20,
    DocumentSnapshot? startAfter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .transactionsCollection(uid)
        .orderBy('date', descending: true)
        .limit(limit);

    if (startDate != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(
          endDate ?? DateTime.now(),
        ),
      );
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    } else if (endDate != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await _getWithCacheFallback(query);
    return (
      transactions: snap.docs.map(TransactionModel.fromFirestore).toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  /// Fetches lightweight (type, amount, category) tuples for ALL transactions
  /// in the date range — no pagination limit. Category filtering is intentionally
  /// left to the caller to avoid composite-index requirements.
  Future<List<({String type, int amount, String category})>> fetchAllForTotals({
    required String uid,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .transactionsCollection(uid)
        .orderBy('date', descending: true);

    if (startDate != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    final snap = await _getWithCacheFallback(query);

    return snap.docs.map((doc) {
      final d = doc.data();
      return (
        type: d['type'] as String? ?? '',
        amount: (d['amount'] as num?)?.toInt() ?? 0,
        category: d['category'] as String? ?? '',
      );
    }).toList();
  }

  /// Fetches transactions within the last [days] days.
  Future<List<TransactionModel>> fetchRecent(String uid, {int days = 90}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final snap = await _getWithCacheFallback(
      _firestore
          .transactionsCollection(uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('date', descending: true),
    );
    return snap.docs.map(TransactionModel.fromFirestore).toList();
  }

  /// Builds a new transaction with a fresh ID, without touching Firestore.
  ///
  /// Separate from [writeTransaction] so callers can commit the model to local
  /// state immediately and hand the write to `SyncService` — offline a Firestore
  /// write future never completes, so it must never gate the UI.
  TransactionModel buildTransaction({
    required String type,
    required int amount,
    required String category,
    String description = '',
    required DateTime date,
  }) =>
      TransactionModel(
        id: _uuid.v4(),
        type: type,
        amount: amount,
        category: category,
        description: description,
        date: date,
        createdAt: DateTime.now(),
        pendingSync: true,
      );

  /// Persists [txn]. Offline this queues to disk and replays on reconnect.
  Future<void> writeTransaction(String uid, TransactionModel txn) {
    return _firestore
        .transactionsCollection(uid)
        .doc(txn.id)
        .set(txn.toFirestore());
  }

  /// Deletes a transaction by ID.
  Future<void> deleteTransaction(String uid, String txnId) async {
    await _firestore.transactionsCollection(uid).doc(txnId).delete();
  }
}
