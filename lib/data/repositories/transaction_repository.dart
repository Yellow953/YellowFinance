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
    required String title,
    String description = '',
    required DateTime date,
  }) async {
    final id = _uuid.v4();
    final txn = TransactionModel(
      id: id,
      type: type,
      amount: amount,
      category: category,
      title: title,
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
