import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/sync_service.dart';
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

  // Cached computed values
  final Rx<List<TransactionModel>> _filteredTransactions =
      Rx<List<TransactionModel>>([]);
  final Rx<List<({DateTime date, List<TransactionModel> txns})>>
      _filteredTransactionsByDay =
      Rx<List<({DateTime date, List<TransactionModel> txns})>>([]);

  // Summary totals for the filtered set
  final RxInt filteredIncomeCents = 0.obs;
  final RxInt filteredExpenseCents = 0.obs;
  final RxInt filteredBalanceCents = 0.obs;

  static const _pageSize = 20;

  // Add transaction form state
  final RxString selectedType = AppConstants.txnExpense.obs;
  final RxString selectedCategory = AppConstants.expenseCategories.first.obs;

  // Filter state
  static const filterPeriods = [
    'Today',
    'Yesterday',
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

  SyncService get _sync => Get.find<SyncService>();

  @override
  void onInit() {
    super.onInit();
    ever(transactions, (List<TransactionModel> list) {
      _recomputeFiltered();
      // Keep the global sync indicator in step with what's actually unsynced.
      _sync.reportPending(
        'transactions',
        list.where((t) => t.pendingSync).length,
      );
    });
    ever(filterCategory, (_) => _recomputeFiltered());
    // Unlike tasks and sports, this list has no snapshot stream to echo server
    // state back — so it needs an explicit re-fetch once the network returns.
    // Totals are re-fetched too: the local deltas only know about writes made
    // on this device, not any made elsewhere while it was offline.
    ever<bool>(Get.find<ConnectivityService>().isOnline, (online) {
      if (online) {
        refresh();
        _fetchTotals();
      }
    });
    _fetchPage(reset: true);
    _fetchTotals();
  }

  @override
  void onClose() {
    _sync.reportPending('transactions', 0);
    super.onClose();
  }

  // ── Date range helpers ──────────────────────────────────────────────────

  /// Midnight at the beginning of [d].
  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Last instant of [d] — used so day-bounded queries are inclusive.
  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  ({DateTime? start, DateTime? end}) get _activeDateRange {
    final now = DateTime.now();
    switch (filterPeriod.value) {
      case 'Today':
        return (start: _startOfDay(now), end: _endOfDay(now));
      case 'Yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        return (start: _startOfDay(yesterday), end: _endOfDay(yesterday));
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
        final s = customStart.value;
        final e = customEnd.value ?? s;
        return (
          start: s == null ? null : _startOfDay(s),
          end: e == null ? null : _endOfDay(e),
        );
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
    _fetchTotals();
  }

  /// Applies a custom range. Pass [end] as null (or equal to [start]) to filter
  /// a single day.
  void setCustomRange(DateTime start, DateTime? end) {
    customStart.value = _startOfDay(start);
    customEnd.value = _endOfDay(end ?? start);
    filterPeriod.value = 'Custom';
    filterCategory.value = 'All';
    _fetchPage(reset: true);
    _fetchTotals();
  }

  void setFilterCategory(String category) {
    filterCategory.value = category;
    _fetchTotals(category: category);
  }

  /// Categories actually present in the currently loaded transactions.
  List<String> get filterCategories {
    return transactions.map((t) => t.category).toSet().toList()..sort();
  }

  // ── Totals fetch (full dataset, accurate) ───────────────────────────────

  Future<void> _fetchTotals({String? category}) async {
    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null) return;

    final range = _activeDateRange;
    try {
      final all = await _txnRepo.fetchAllForTotals(
        uid: uid,
        startDate: range.start,
        endDate: range.end,
      );

      final cat = category ?? filterCategory.value;
      final data = cat == 'All' ? all : all.where((t) => t.category == cat);

      int income = 0;
      int expense = 0;
      for (final t in data) {
        if (t.type == 'income') {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }
      filteredIncomeCents.value = income;
      filteredExpenseCents.value = expense;
      filteredBalanceCents.value = income - expense;
    } catch (_) {
      // Silently ignore — totals are best-effort
    }
  }

  // ── Recompute filter cache ────────────────────────────────────────────────

  void _recomputeFiltered() {
    final cat = filterCategory.value;
    final filtered = cat == 'All'
        ? transactions.toList()
        : transactions.where((t) => t.category == cat).toList();
    _filteredTransactions.value = filtered;

    final grouped = <String, List<TransactionModel>>{};
    for (final t in filtered) {
      final key =
          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
      (grouped[key] ??= []).add(t);
    }
    _filteredTransactionsByDay.value = grouped.entries.map((e) {
      final parts = e.key.split('-');
      return (
        date: DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
        txns: e.value..sort((a, b) => b.date.compareTo(a.date)),
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Transactions after client-side category filter.
  List<TransactionModel> get filteredTransactions =>
      _filteredTransactions.value;

  /// Filtered transactions grouped by day, newest first.
  List<({DateTime date, List<TransactionModel> txns})>
      get filteredTransactionsByDay => _filteredTransactionsByDay.value;

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
      final txn = _txnRepo.buildTransaction(
        type: selectedType.value,
        amount: amountCents,
        category: selectedCategory.value,
        description: description,
        date: date,
      );

      // Commit locally first — a Firestore write future never completes while
      // offline, so nothing user-visible may wait on it. The list is ordered by
      // date descending, so insert at the matching position rather than the top.
      if (_inActiveRange(txn.date)) {
        _insertByDate(txn);
        _applyTotalsDelta(txn, add: true);
      }

      Get.back();
      AppSnackbar.saved('Transaction added');

      _sync.enqueue(
        () => _txnRepo.writeTransaction(uid, txn),
        label: 'transaction',
        onSynced: () => _markSynced(txn.id),
        onError: () {
          transactions.removeWhere((t) => t.id == txn.id);
          _applyTotalsDelta(txn, add: false);
        },
      );
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
    final idx = transactions.indexWhere((t) => t.id == txnId);
    if (idx == -1) return;
    final removed = transactions[idx];

    transactions.removeAt(idx);
    _applyTotalsDelta(removed, add: false);

    _sync.enqueue(
      () => _txnRepo.deleteTransaction(uid, txnId),
      label: 'transaction',
      isDelete: true,
      onError: () {
        transactions.insert(idx.clamp(0, transactions.length), removed);
        _applyTotalsDelta(removed, add: true);
      },
    );
  }

  // ── Optimistic-write helpers ────────────────────────────────────────────

  /// Whether [date] falls inside the period filter currently applied.
  bool _inActiveRange(DateTime date) {
    final range = _activeDateRange;
    if (range.start != null && date.isBefore(range.start!)) return false;
    if (range.end != null && date.isAfter(range.end!)) return false;
    return true;
  }

  /// Inserts [txn] preserving the date-descending order of the loaded page.
  ///
  /// Ordering is only guaranteed against items already loaded — backdating a
  /// transaction to before the pagination cursor parks it at the end of the
  /// list until the next refresh. Showing it in a slightly odd position beats
  /// swallowing it with no feedback.
  void _insertByDate(TransactionModel txn) {
    final idx = transactions.indexWhere((t) => t.date.isBefore(txn.date));
    transactions.insert(idx == -1 ? transactions.length : idx, txn);
  }

  /// Adjusts the summary totals by [txn] instead of re-querying the whole range.
  ///
  /// Respects the active category filter so the totals stay consistent with
  /// what `_fetchTotals` would have computed.
  void _applyTotalsDelta(TransactionModel txn, {required bool add}) {
    final cat = filterCategory.value;
    if (cat != 'All' && txn.category != cat) return;
    final sign = add ? 1 : -1;
    if (txn.isIncome) {
      filteredIncomeCents.value += sign * txn.amount;
    } else {
      filteredExpenseCents.value += sign * txn.amount;
    }
    filteredBalanceCents.value =
        filteredIncomeCents.value - filteredExpenseCents.value;
  }

  /// Clears the pending flag once the server acknowledges the write.
  ///
  /// Tasks and sports get this for free from their snapshot stream; this list
  /// is paginated, so it has to be done by hand.
  void _markSynced(String id) {
    final idx = transactions.indexWhere((t) => t.id == id);
    if (idx != -1) {
      transactions[idx] = transactions[idx].copyWith(pendingSync: false);
    }
  }
}
