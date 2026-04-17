import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single workout / activity log entry.
class SportRecordModel {
  final String id;
  final DateTime date;         // date only (no time), used for day-grouping
  final String category;
  final String description;    // free text, e.g. "50 PU, 100 ABS"
  final DateTime createdAt;
  final String? userId;        // set when read from all_sports collection
  final String? userName;      // display name snapshot, set at write time

  const SportRecordModel({
    required this.id,
    required this.date,
    required this.category,
    required this.description,
    required this.createdAt,
    this.userId,
    this.userName,
  });

  factory SportRecordModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SportRecordModel(
      id: doc.id,
      date: (d['date'] as Timestamp).toDate(),
      category: d['category'] as String? ?? '',
      description: d['description'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      userId: d['userId'] as String?,
      userName: d['userName'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'date': Timestamp.fromDate(date),
        'category': category,
        'description': description,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Map<String, dynamic> toAllSportsFirestore({
    required String uid,
    required String displayName,
  }) => {
        ...toFirestore(),
        'userId': uid,
        'userName': displayName,
      };
}
