import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../auth/controllers/auth_controller.dart';

/// Manages the full transactions list and add-transaction form.
class TransactionController extends GetxController {
  final TransactionRepository _txnRepo;

  final RxList<TransactionModel> transactions = <TransactionModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;

  DocumentSnapshot? _lastDoc;

  static const _pageSize = 20;

  // Add transaction form state
  final RxString selectedType = AppConstants.txnExpense.obs;
  final RxString selectedCategory = AppConstants.expenseCategories.first.obs;

  // Filter state
  static const filterPeriods = [
    'This Month',
    'Last Month',
    '3 Months',
    'This Year',
    'All',
  ];

  final RxString filterPeriod = 'This Month'.obs;
  final RxString filterCategory = 'All'.obs;
  final Rxn<DateTime> customStart = Rxn<DateTime>();
  final Rxn<DateTime> customEnd = Rxn<DateTime>();

  TransactionController({required TransactionRepository txnRepo})
      : _txnRepo = txnRepo;

  @override
  void onInit() {
    super.onInit();
    _fetchPage(reset: true);
  }

  // ── Date range helpers ──────────────────────────────────────────────────

  ({DateTime? start, DateTime? end}) get _activeDateRange {
    final now = DateTime.now();
    switch (filterPeriod.value) {
      case 'This Month':
        return (start: DateTime(now.year, now.month, 1), end: now);
      case 'Last Month':
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 1)
            .subtract(const Duration(seconds: 1));
        return (start: start, end: end);
      case '3 Months':
        return (
          start: DateTime(now.year, now.month - 2, 1),
          end: now,
        );
      case 'This Year':
        return (start: DateTime(now.year, 1, 1), end: now);
      case 'Custom':
        return (start: customStart.value, end: customEnd.value);
      default: // 'All'
        return (start: null, end: null);
    }
  }

  // ── Pagination ──────────────────────────────────────────────────────────

  Future<void> _fetchPage({bool reset = false}) async {
    if (reset) {
      _lastDoc = null;
      hasMore.value = true;
      isLoading.value = true;
    } else {
      if (!hasMore.value || isLoadingMore.value) return;
      isLoadingMore.value = true;
    }

    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null) {
      isLoading.value = false;
      isLoadingMore.value = false;
      return;
    }

    try {
      final range = _activeDateRange;
      final result = await _txnRepo.fetchPage(
        uid: uid,
        limit: _pageSize,
        startAfter: reset ? null : _lastDoc,
        startDate: range.start,
        endDate: range.end,
      );

      if (reset) {
        transactions.assignAll(result.transactions);
      } else {
        transactions.addAll(result.transactions);
      }

      _lastDoc = result.lastDoc;
      hasMore.value = result.transactions.length == _pageSize;
    } catch (_) {
      AppSnackbar.error('Could not load transactions.');
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  /// Call this when the list scrolls near the bottom.
  void loadNextPage() => _fetchPage(reset: false);

  /// Pull-to-refresh.
  @override
  Future<void> refresh() => _fetchPage(reset: true);

  // ── Filters ─────────────────────────────────────────────────────────────

  void setFilterPeriod(String period) {
    filterPeriod.value = period;
    filterCategory.value = 'All';
    _fetchPage(reset: true);
  }

  void setCustomRange(DateTime start, DateTime end) {
    customStart.value = start;
    customEnd.value = end;
    filterPeriod.value = 'Custom';
    filterCategory.value = 'All';
    _fetchPage(reset: true);
  }

  void setFilterCategory(String category) {
    filterCategory.value = category;
  }

  /// Categories actually present in the currently loaded transactions.
  List<String> get filterCategories {
    return transactions.map((t) => t.category).toSet().toList()..sort();
  }

  /// Transactions after client-side category filter.
  List<TransactionModel> get filteredTransactions {
    if (filterCategory.value == 'All') return transactions.toList();
    return transactions
        .where((t) => t.category == filterCategory.value)
        .toList();
  }

  /// Filtered transactions grouped by day, newest first.
  List<({DateTime date, List<TransactionModel> txns})>
      get filteredTransactionsByDay {
    final list = filteredTransactions;
    final grouped = <String, List<TransactionModel>>{};
    for (final t in list) {
      final key =
          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
      (grouped[key] ??= []).add(t);
    }
    return grouped.entries.map((e) {
      final parts = e.key.split('-');
      return (
        date: DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
        txns: e.value..sort((a, b) => b.date.compareTo(a.date)),
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // ── Form helpers ────────────────────────────────────────────────────────

  /// Switches the type and resets the category picker.
  void setType(String type) {
    selectedType.value = type;
    selectedCategory.value = type == AppConstants.txnIncome
        ? AppConstants.incomeCategories.first
        : AppConstants.expenseCategories.first;
  }

  List<String> get categories => selectedType.value == AppConstants.txnIncome
      ? AppConstants.incomeCategories
      : AppConstants.expenseCategories;

  // ── CRUD ────────────────────────────────────────────────────────────────

  /// Saves a new transaction.
  Future<void> addTransaction({
    required String amountText,
    String description = '',
    required DateTime date,
  }) async {
    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null) return;

    final parsed = double.tryParse(amountText.replaceAll(',', ''));
    if (parsed == null || parsed <= 0) return;
    final amountCents = (parsed * 100).round();

    isSaving.value = true;
    try {
      await _txnRepo.addTransaction(
        uid: uid,
        type: selectedType.value,
        amount: amountCents,
        category: selectedCategory.value,
        description: description,
        date: date,
      );
      Get.back();
      AppSnackbar.success('Transaction added');
      // Refresh so the new transaction appears.
      await refresh();
    } catch (e) {
      AppSnackbar.error('Could not save transaction.');
    } finally {
      isSaving.value = false;
    }
  }

  /// Deletes a transaction.
  Future<void> deleteTransaction(String txnId) async {
    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null) return;
    try {
      await _txnRepo.deleteTransaction(uid, txnId);
      transactions.removeWhere((t) => t.id == txnId);
    } catch (_) {
      AppSnackbar.error('Could not delete transaction.');
    }
  }
}
