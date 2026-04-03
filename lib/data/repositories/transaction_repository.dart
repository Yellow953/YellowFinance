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

  /// Streams all transactions for [uid] ordered by date descending.
  Stream<List<TransactionModel>> watchTransactions(String uid) {
    return _firestore
        .transactionsCollection(uid)
        .orderBy('date', descending: true)
        .snapshots()
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

    final snap = await query
        .get(const GetOptions(source: Source.serverAndCache))
        .timeout(const Duration(seconds: 10));
    return (
      transactions: snap.docs.map(TransactionModel.fromFirestore).toList(),
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  /// Fetches transactions within the last [days] days.
  Future<List<TransactionModel>> fetchRecent(String uid, {int days = 90}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final snap = await _firestore
        .transactionsCollection(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map(TransactionModel.fromFirestore).toList();
  }

  /// Adds a new transaction document.
  Future<TransactionModel> addTransaction({
    required String uid,
    required String type,
    required int amount,
    required String category,
    String description = '',
    required DateTime date,
  }) async {
    final id = _uuid.v4();
    final txn = TransactionModel(
      id: id,
      type: type,
      amount: amount,
      category: category,
      description: description,
      date: date,
      createdAt: DateTime.now(),
    );
    await _firestore
        .transactionsCollection(uid)
        .doc(id)
        .set(txn.toFirestore());
    return txn;
  }

  /// Deletes a transaction by ID.
  Future<void> deleteTransaction(String uid, String txnId) async {
    await _firestore.transactionsCollection(uid).doc(txnId).delete();
  }
}
