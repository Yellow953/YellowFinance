import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

/// Represents a single income or expense transaction.
/// [amount] is stored in cents (integer) to avoid floating-point errors.
class TransactionModel extends Equatable {
  final String id;
  final String type; // 'income' | 'expense'
  final int amount; // cents
  final String category;
  final String description; // optional, may be empty
  final DateTime date;
  final DateTime createdAt;

  /// True while this transaction has a local write not yet acknowledged by the
  /// server. Client-derived state — never written to the document.
  final bool pendingSync;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.description = '',
    required this.date,
    required this.createdAt,
    this.pendingSync = false,
  });

  bool get isIncome => type == AppConstants.txnIncome;
  bool get isExpense => type == AppConstants.txnExpense;

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      type: data['type'] as String? ?? AppConstants.txnExpense,
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      category: data['category'] as String? ?? '',
      description: data['description'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pendingSync: doc.metadata.hasPendingWrites,
    );
  }

  TransactionModel copyWith({bool? pendingSync}) => TransactionModel(
        id: id,
        type: type,
        amount: amount,
        category: category,
        description: description,
        date: date,
        createdAt: createdAt,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  Map<String, dynamic> toFirestore() => {
        'type': type,
        'amount': amount,
        'category': category,
        'description': description,
        'date': Timestamp.fromDate(date),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  @override
  List<Object?> get props =>
      [id, type, amount, category, description, date, pendingSync];
}
