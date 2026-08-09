import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// A savings goal — an emergency fund, a trip, a deposit.
///
/// Unlike a budget, a goal is not tied to a month or a category: it accumulates
/// until [targetCents] is reached. [savedCents] is maintained by explicit
/// contributions rather than being derived from transactions, so money the user
/// mentally sets aside isn't double-counted against their spending.
class GoalModel extends Equatable {
  final String id;
  final String title;
  final int targetCents;
  final int savedCents;

  /// Optional date the user wants to hit the target by.
  final DateTime? deadline;
  final DateTime createdAt;

  /// True while this goal has a local write not yet acknowledged by the server.
  /// Client-derived state — never written to the document.
  final bool pendingSync;

  const GoalModel({
    required this.id,
    required this.title,
    required this.targetCents,
    required this.savedCents,
    required this.deadline,
    required this.createdAt,
    this.pendingSync = false,
  });

  /// Progress in the range 0..1, clamped so an over-funded goal doesn't
  /// overflow its progress bar.
  double get progress =>
      targetCents <= 0 ? 0 : (savedCents / targetCents).clamp(0.0, 1.0);

  bool get isComplete => savedCents >= targetCents && targetCents > 0;

  /// Cents still needed, never negative.
  int get remainingCents =>
      (targetCents - savedCents) < 0 ? 0 : targetCents - savedCents;

  factory GoalModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GoalModel(
      id: doc.id,
      title: d['title'] as String? ?? '',
      targetCents: (d['targetCents'] as num?)?.toInt() ?? 0,
      savedCents: (d['savedCents'] as num?)?.toInt() ?? 0,
      deadline: (d['deadline'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pendingSync: doc.metadata.hasPendingWrites,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'targetCents': targetCents,
        'savedCents': savedCents,
        'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  GoalModel copyWith({
    String? title,
    int? targetCents,
    int? savedCents,
    DateTime? deadline,
    bool clearDeadline = false,
    bool? pendingSync,
  }) =>
      GoalModel(
        id: id,
        title: title ?? this.title,
        targetCents: targetCents ?? this.targetCents,
        savedCents: savedCents ?? this.savedCents,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
        createdAt: createdAt,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  @override
  List<Object?> get props =>
      [id, title, targetCents, savedCents, deadline, pendingSync];
}
