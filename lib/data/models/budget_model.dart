import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

/// A monthly spending cap or earning target covering one or more categories.
///
/// [limitCents] is stored in cents (integer) to avoid floating-point errors,
/// matching [TransactionModel].
///
/// The [type] flips the meaning of progress: on an expense budget going over
/// the limit is a failure, on an income budget it is the goal.
class BudgetModel extends Equatable {
  final String id;

  /// 'expense' (a spending cap) | 'income' (an earning target).
  final String type;

  /// The categories this budget measures. A single-element list holding
  /// [AppConstants.budgetAllCategories] means "every category of this type",
  /// so a category added to `AppConstants` later is covered automatically.
  final List<String> categories;

  /// User-supplied name for a grouped budget — "Essentials", "Fun". Empty for
  /// budgets that are adequately described by their categories.
  final String name;

  final int limitCents;

  /// The calendar month this budget applies to, normalized to the 1st at
  /// midnight. A budget is scoped to one month, so changing next month's limit
  /// never rewrites the history of what was budgeted this month.
  final DateTime month;

  final DateTime createdAt;

  /// True while this budget has a local write not yet acknowledged by the
  /// server. Client-derived state — never written to the document.
  final bool pendingSync;

  const BudgetModel({
    required this.id,
    required this.type,
    required this.categories,
    required this.limitCents,
    required this.month,
    required this.createdAt,
    this.name = '',
    this.pendingSync = false,
  });

  /// Normalizes any date to the 1st of its month at midnight — the canonical
  /// form for [month], so equality comparisons are safe.
  static DateTime monthOf(DateTime date) => DateTime(date.year, date.month);

  bool get isIncome => type == AppConstants.txnIncome;
  bool get isExpense => type == AppConstants.txnExpense;

  /// Whether this budget covers every category of its type.
  bool get isAllCategories =>
      categories.isEmpty ||
      categories.contains(AppConstants.budgetAllCategories);

  /// Whether a transaction in [category] counts toward this budget.
  bool covers(String category) =>
      isAllCategories || categories.contains(category);

  /// Headline for the budget row.
  ///
  /// A user-supplied [name] always wins. Otherwise a single category names
  /// itself, and a group falls back to listing its categories.
  String get label {
    if (name.isNotEmpty) return name;
    if (isAllCategories) return isIncome ? 'All income' : 'All expenses';
    if (categories.length == 1) return categories.first;
    return categories.join(' + ');
  }

  /// Secondary line listing what a grouped budget covers, or empty when the
  /// [label] already says everything.
  String get subtitle {
    if (isAllCategories) return '';
    if (name.isEmpty && categories.length <= 1) return '';
    return categories.join(', ');
  }

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final createdAt =
        (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Budgets written before budgets could span categories carry a single
    // `category` string; promote it to a one-element list so existing data
    // keeps working untouched.
    final raw = d['categories'];
    final categories = raw is List
        ? raw.whereType<String>().toList()
        : [d['category'] as String? ?? AppConstants.budgetAllCategories];

    return BudgetModel(
      id: doc.id,
      type: d['type'] as String? ?? AppConstants.txnExpense,
      categories: categories,
      name: d['name'] as String? ?? '',
      limitCents: (d['limitCents'] as num?)?.toInt() ?? 0,
      // Likewise, budgets written before budgets became month-scoped carry no
      // month; fall back to the month they were created in.
      month: monthOf((d['month'] as Timestamp?)?.toDate() ?? createdAt),
      createdAt: createdAt,
      pendingSync: doc.metadata.hasPendingWrites,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type,
        'categories': categories,
        'name': name,
        'limitCents': limitCents,
        'month': Timestamp.fromDate(month),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  BudgetModel copyWith({
    String? type,
    List<String>? categories,
    String? name,
    int? limitCents,
    DateTime? month,
    bool? pendingSync,
  }) =>
      BudgetModel(
        id: id,
        type: type ?? this.type,
        categories: categories ?? this.categories,
        name: name ?? this.name,
        limitCents: limitCents ?? this.limitCents,
        month: month ?? this.month,
        createdAt: createdAt,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  @override
  List<Object?> get props =>
      [id, type, categories, name, limitCents, month, pendingSync];
}
