import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/models/sport_record_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../auth/controllers/auth_controller.dart';

/// Aggregates transaction data for charts and monthly breakdowns.
class ReportsController extends GetxController {
  final TransactionRepository _txnRepo;

  final RxList<TransactionModel> transactions = <TransactionModel>[].obs;
  final RxList<SportRecordModel> sportRecords = <SportRecordModel>[].obs;
  final RxBool isLoading = false.obs;
  final Rx<DateTime> selectedMonth = DateTime.now().obs;
  final RxInt touchedPieIndex = (-1).obs;
  final Rx<Set<String>> hiddenPieCategories = Rx<Set<String>>(<String>{});

  // Cached computed values — updated only when inputs change
  final Rx<List<TransactionModel>> _monthlyTransactions =
      Rx<List<TransactionModel>>([]);
  final Rx<List<({DateTime month, int incomeCents, int expenseCents})>>
      _monthlyTotals =
      Rx<List<({DateTime month, int incomeCents, int expenseCents})>>([]);
  final Rx<Map<String, int>> _expenseCategoryMap = Rx<Map<String, int>>({});
  final Rx<List<({DateTime date, List<TransactionModel> txns})>>
      _transactionsByDay =
      Rx<List<({DateTime date, List<TransactionModel> txns})>>([]);
  final Rx<List<SportRecordModel>> _monthlySportRecords =
      Rx<List<SportRecordModel>>([]);
  final Rx<Map<String, int>> _sportCategoryMap = Rx<Map<String, int>>({});

  ReportsController({required TransactionRepository txnRepo})
      : _txnRepo = txnRepo;

  @override
  void onInit() {
    super.onInit();
    ever(transactions, (_) => _recomputeTransactions());
    ever(selectedMonth, (_) => _recomputeTransactions());
    ever(sportRecords, (_) => _recomputeSports());
    ever(selectedMonth, (_) => _recomputeSports());
    loadData();
  }

  Future<void> loadData() async {
    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null) return;
    isLoading.value = true;
    try {
      final results = await Future.wait([
        _txnRepo.fetchRecent(uid, days: 365),
        _fetchSportRecords(uid),
      ]);
      transactions.assignAll(results[0] as List<TransactionModel>);
      sportRecords.assignAll(results[1] as List<SportRecordModel>);
    } catch (_) {
      AppSnackbar.error('Could not load reports.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<SportRecordModel>> _fetchSportRecords(String uid) async {
    final since = DateTime.now().subtract(const Duration(days: 365));
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sports')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map(SportRecordModel.fromFirestore).toList();
  }

  // ── Recompute caches ──────────────────────────────────────────────────────

  void _recomputeTransactions() {
    final m = selectedMonth.value;
    final monthly = transactions
        .where((t) => t.date.year == m.year && t.date.month == m.month)
        .toList();
    _monthlyTransactions.value = monthly;

    // 6-month bar chart totals
    final now = DateTime.now();
    _monthlyTotals.value = List.generate(6, (i) {
      final month = DateTime(now.year, now.month - (5 - i));
      int income = 0, expense = 0;
      for (final t in transactions) {
        if (t.date.year == month.year && t.date.month == month.month) {
          if (t.isIncome) {
            income += t.amount;
          } else {
            expense += t.amount;
          }
        }
      }
      return (month: month, incomeCents: income, expenseCents: expense);
    });

    // Expense category map
    final catMap = <String, int>{};
    for (final t in monthly.where((t) => t.isExpense)) {
      catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
    }
    _expenseCategoryMap.value = Map.fromEntries(
        catMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));

    // Transactions grouped by day
    final grouped = <String, List<TransactionModel>>{};
    for (final t in monthly) {
      final key =
          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
      (grouped[key] ??= []).add(t);
    }
    _transactionsByDay.value = grouped.entries.map((e) {
      final parts = e.key.split('-');
      return (
        date: DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
        txns: e.value..sort((a, b) => b.date.compareTo(a.date)),
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void _recomputeSports() {
    final m = selectedMonth.value;
    final monthly = sportRecords
        .where((r) => r.date.year == m.year && r.date.month == m.month)
        .toList();
    _monthlySportRecords.value = monthly;

    final map = <String, int>{};
    for (final r in monthly) {
      map[r.category] = (map[r.category] ?? 0) + 1;
    }
    _sportCategoryMap.value = Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  // ── Public getters — read from cached Rx values ───────────────────────────

  List<TransactionModel> get monthlyTransactions => _monthlyTransactions.value;

  List<({DateTime month, int incomeCents, int expenseCents})> get monthlyTotals =>
      _monthlyTotals.value;

  Map<String, int> get expenseCategoryMap => _expenseCategoryMap.value;

  List<({DateTime date, List<TransactionModel> txns})> get transactionsByDay =>
      _transactionsByDay.value;

  List<SportRecordModel> get monthlySportRecords => _monthlySportRecords.value;

  Map<String, int> get sportCategoryMap => _sportCategoryMap.value;

  int get monthlyIncomeCents => monthlyTransactions
      .where((t) => t.isIncome)
      .fold(0, (s, t) => s + t.amount);

  int get monthlyExpenseCents => monthlyTransactions
      .where((t) => t.isExpense)
      .fold(0, (s, t) => s + t.amount);

  /// Most recent 5 sport records across all months.
  List<SportRecordModel> get recentSportRecords =>
      sportRecords.take(5).toList();

  // ── Month navigation ──────────────────────────────────────────────────────

  void togglePieCategory(String category) {
    final next = {...hiddenPieCategories.value};
    if (next.contains(category)) {
      next.remove(category);
    } else {
      next.add(category);
    }
    hiddenPieCategories.value = next;
    touchedPieIndex.value = -1;
  }

  void setSelectedMonth(DateTime month) {
    selectedMonth.value = month;
    touchedPieIndex.value = -1;
    hiddenPieCategories.value = <String>{};
  }

  void previousMonth() {
    final m = selectedMonth.value;
    selectedMonth.value = DateTime(m.year, m.month - 1);
  }

  void nextMonth() {
    final m = selectedMonth.value;
    final next = DateTime(m.year, m.month + 1);
    final now = DateTime.now();
    final cap = DateTime(now.year, now.month);
    if (!next.isAfter(cap)) {
      selectedMonth.value = next;
    }
  }
}
