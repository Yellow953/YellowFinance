import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/goal_model.dart';
import '../providers/firestore_provider.dart';

/// CRUD operations for savings goals.
class GoalRepository {
  final FirestoreProvider _firestore;
  final _uuid = const Uuid();

  GoalRepository({required FirestoreProvider firestore})
      : _firestore = firestore;

  /// Streams every goal for [uid], newest first.
  ///
  /// `includeMetadataChanges` is required so the stream re-emits when a write
  /// is acknowledged — see [BudgetRepository.watchBudgets].
  Stream<List<GoalModel>> watchGoals(String uid) => _firestore
      .goalsCollection(uid)
      .orderBy('createdAt', descending: true)
      .snapshots(includeMetadataChanges: true)
      .map((snap) => snap.docs.map(GoalModel.fromFirestore).toList());

  /// Builds a goal with a fresh ID without touching Firestore, so the caller
  /// can commit it locally and hand the write to `SyncService`.
  GoalModel buildGoal({
    required String title,
    required int targetCents,
    int savedCents = 0,
    DateTime? deadline,
  }) =>
      GoalModel(
        id: _uuid.v4(),
        title: title,
        targetCents: targetCents,
        savedCents: savedCents,
        deadline: deadline,
        createdAt: DateTime.now(),
        pendingSync: true,
      );

  /// Persists [goal]. Offline this queues to disk and replays on reconnect.
  Future<void> writeGoal(String uid, GoalModel goal) =>
      _firestore.goalsCollection(uid).doc(goal.id).set(goal.toFirestore());

  /// Overwrites the editable fields of an existing goal.
  Future<void> updateGoal(String uid, GoalModel goal) =>
      _firestore.goalsCollection(uid).doc(goal.id).update({
        'title': goal.title,
        'targetCents': goal.targetCents,
        'savedCents': goal.savedCents,
        'deadline':
            goal.deadline != null ? Timestamp.fromDate(goal.deadline!) : null,
      });

  /// Sets the saved amount — used by contribute / withdraw.
  Future<void> updateSaved(String uid, String goalId, int savedCents) =>
      _firestore
          .goalsCollection(uid)
          .doc(goalId)
          .update({'savedCents': savedCents});

  Future<void> deleteGoal(String uid, String goalId) =>
      _firestore.goalsCollection(uid).doc(goalId).delete();
}
