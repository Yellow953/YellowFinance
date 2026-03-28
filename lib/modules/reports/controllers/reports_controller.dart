import 'package:get/get.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../auth/controllers/auth_controller.dart';

/// Aggregates transaction data for charts and monthly breakdowns.
class ReportsController extends GetxController {
  final TransactionRepository _txnRepo;

  final RxList<TransactionModel> transactions = <TransactionModel>[].obs;
  final RxBool isLoading = false.obs;
  final Rx<DateTime> selectedMonth = DateTime.now().obs;

  ReportsController({required TransactionRepository txnRepo})
      : _txnRepo = txnRepo;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null) return;
    isLoading.value = true;
    try {
      final data = await _txnRepo.fetchRecent(uid, days: 365);
      transactions.assignAll(data);
    } catch (_) {
      AppSnackbar.error('Could not load reports.');
    } finally {
      isLoading.value = false;
    }
  }

  /// Transactions in the selected month.
  List<TransactionModel> get monthlyTransactions {
    final m = selectedMonth.value;
    return transactions
        .where((t) =>
            t.date.year == m.year && t.date.month == m.month)
        .toList();
  }

  int get monthlyIncomeCents => monthlyTransactions
      .where((t) => t.isIncome)
      .fold(0, (s, t) => s + t.amount);

  int get monthlyExpenseCents => monthlyTransactions
      .where((t) => t.isExpense)
      .fold(0, (s, t) => s + t.amount);

  /// Returns monthly totals for the last 6 months (for bar chart).
  List<({DateTime month, int incomeCents, int expenseCents})> get monthlyTotals {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final m = DateTime(now.year, now.month - (5 - i));
      final txns = transactions.where(
          (t) => t.date.year == m.year && t.date.month == m.month);
      int income = 0, expense = 0;
      for (final t in txns) {
        if (t.isIncome) {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }
      return (month: m, incomeCents: income, expenseCents: expense);
    });
  }

  /// Category breakdown for expenses in selected month.
  Map<String, int> get expenseCategoryMap {
    final map = <String, int>{};
    for (final t in monthlyTransactions.where((t) => t.isExpense)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  void previousMonth() {
    final m = selectedMonth.value;
    selectedMonth.value = DateTime(m.year, m.month - 1);
  }

  void nextMonth() {
    final m = selectedMonth.value;
    final next = DateTime(m.year, m.month + 1);
    if (next.isBefore(DateTime.now()) ||
        (next.year == DateTime.now().year &&
            next.month == DateTime.now().month)) {
      selectedMonth.value = next;
    }
  }
}
