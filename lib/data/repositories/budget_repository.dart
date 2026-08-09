import 'package:uuid/uuid.dart';
import '../models/budget_model.dart';
import '../providers/firestore_provider.dart';

/// CRUD operations for monthly category budgets.
class BudgetRepository {
  final FirestoreProvider _firestore;
  final _uuid = const Uuid();

  BudgetRepository({required FirestoreProvider firestore})
      : _firestore = firestore;

  /// Streams every budget for [uid], newest first.
  ///
  /// `includeMetadataChanges` is required, not cosmetic: `pendingSync` is read
  /// from `hasPendingWrites`, and a server acknowledgement changes *only* that
  /// metadata. Without this the stream never re-emits on ack, so the flag —
  /// and the "Syncing…" banner it drives — would stay stuck on forever.
  Stream<List<BudgetModel>> watchBudgets(String uid) => _firestore
      .budgetsCollection(uid)
      .orderBy('createdAt', descending: true)
      .snapshots(includeMetadataChanges: true)
      .map((snap) => snap.docs.map(BudgetModel.fromFirestore).toList());

  /// Builds a budget with a fresh ID without touching Firestore, so the caller
  /// can commit it locally and hand the write to `SyncService`.
  BudgetModel buildBudget({
    required String type,
    required List<String> categories,
    required int limitCents,
    required DateTime month,
    String name = '',
  }) =>
      BudgetModel(
        id: _uuid.v4(),
        type: type,
        categories: categories,
        name: name,
        limitCents: limitCents,
        month: BudgetModel.monthOf(month),
        createdAt: DateTime.now(),
        pendingSync: true,
      );

  /// Persists [budget]. Offline this queues to disk and replays on reconnect.
  Future<void> writeBudget(String uid, BudgetModel budget) => _firestore
      .budgetsCollection(uid)
      .doc(budget.id)
      .set(budget.toFirestore());

  /// Updates the editable fields of an existing budget. The month is not among
  /// them — moving a budget between months would rewrite what was budgeted in
  /// the month it came from.
  Future<void> updateBudget(String uid, BudgetModel budget) =>
      _firestore.budgetsCollection(uid).doc(budget.id).update({
        'categories': budget.categories,
        'name': budget.name,
        'limitCents': budget.limitCents,
      });

  Future<void> deleteBudget(String uid, String budgetId) =>
      _firestore.budgetsCollection(uid).doc(budgetId).delete();
}
