import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single to-do / task item.
class TodoModel {
  final String id;
  final String title;
  final String note;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime createdAt;

  const TodoModel({
    required this.id,
    required this.title,
    required this.note,
    required this.dueDate,
    required this.isCompleted,
    required this.createdAt,
  });

  factory TodoModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TodoModel(
      id: doc.id,
      title: d['title'] as String? ?? '',
      note: d['note'] as String? ?? '',
      dueDate: d['dueDate'] != null
          ? (d['dueDate'] as Timestamp).toDate()
          : null,
      isCompleted: d['isCompleted'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'note': note,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
        'isCompleted': isCompleted,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  TodoModel copyWith({
    String? title,
    String? note,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? isCompleted,
  }) =>
      TodoModel(
        id: id,
        title: title ?? this.title,
        note: note ?? this.note,
        dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
        isCompleted: isCompleted ?? this.isCompleted,
        createdAt: createdAt,
      );
}
