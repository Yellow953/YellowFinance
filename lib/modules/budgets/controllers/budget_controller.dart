import 'dart:async';

import 'package:get/get.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/mixins/auth_scoped_controller.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/models/budget_model.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/transaction_repository.dart';

/// A budget paired with what the user actually did against it this month.
typedef BudgetProgress = ({
  BudgetModel budget,
  int actualCents,
});

/// Drives the Budgets & Goals screen.
///
/// Budgets are evaluated per calendar month: the limit is fixed, the actual is
/// recomputed from the transaction stream whenever transactions or the selected
/// month change. Nothing about progress is persisted — it is always derived, so
/// editing or deleting a transaction is reflected immediately and there is no
/// stored total that can drift out of step with the ledger.
class BudgetController extends GetxController with AuthScopedController {
  final BudgetRepository _budgetRepo;
  final GoalRepository _goalRepo;
  final TransactionRepository _txnRepo;

  final RxList<BudgetModel> budgets = <BudgetModel>[].obs;
  final RxList<GoalModel> goals = <GoalModel>[].obs;
  final RxList<TransactionModel> _transactions = <TransactionModel>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  /// Month whose progress is on screen, normalized to the 1st at midnight.
  late final Rx<DateTime> selectedMonth;

  /// Tab: 0 = budgets, 1 = goals.
  final RxInt tabIndex = 0.obs;

  StreamSubscription<List<BudgetModel>>? _budgetSub;
  StreamSubscription<List<GoalModel>>? _goalSub;
  StreamSubscription<List<TransactionModel>>? _txnSub;

  BudgetController({
    required BudgetRepository budgetRepo,
    required GoalRepository goalRepo,
    required TransactionRepository txnRepo,
  })  : _budgetRepo = budgetRepo,
        _goalRepo = goalRepo,
        _txnRepo = txnRepo;

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month).obs;

    // Keep the global sync indicator in step with what's actually unsynced.
    ever(budgets, (List<BudgetModel> list) {
      _sync.reportPending('budgets', list.where((b) => b.pendingSync).length);
    });
    ever(goals, (List<GoalModel> list) {
      _sync.reportPending('goals', list.where((g) => g.pendingSync).length);
    });

    bindToAuth();
  }

  @override
  void onUserBound(String uid) => _subscribe();

  @override
  void onUserUnbound() {
    _budgetSub?.cancel();
    _goalSub?.cancel();
    _txnSub?.cancel();
    _budgetSub = null;
    _goalSub = null;
    _txnSub = null;
    budgets.clear();
    goals.clear();
    _transactions.clear();
    // Progress is derived from the transaction list, so its memo has to go too
    // — otherwise the next account's first render reuses the old totals.
    _totalsCache.clear();
    _txnRevision.value++;
    _budgetsLoaded = false;
    _txnsLoaded = false;
    isLoading.value = false;
    _sync.reportPending('budgets', 0);
    _sync.reportPending('goals', 0);
  }

  String? get _uid => boundUid;

  SyncService get _sync => Get.find<SyncService>();

  void _subscribe() {
    final uid = _uid;
    if (uid == null) return;
    isLoading.value = true;

    _budgetSub = _budgetRepo.watchBudgets(uid).listen(
      (list) {
        budgets.assignAll(list);
        _budgetsLoaded = true;
        _settleLoading();
      },
      onError: (_) {
        AppSnackbar.error('Could not load budgets.');
        _budgetsLoaded = true;
        _settleLoading();
      },
    );

    _goalSub = _goalRepo.watchGoals(uid).listen(
      (list) => goals.assignAll(list),
      onError: (_) => AppSnackbar.error('Could not load goals.'),
    );

    // Progress is derived from the same stream Home and Transactions use, so a
    // transaction added anywhere moves the budget bars without a refresh.
    _txnSub = _txnRepo.watchTransactions(uid).listen(
      (list) {
        _transactions.assignAll(list);
        // Drop the memoized totals and bump the revision so dependent Obx
        // scopes recompute against the new data.
        _totalsCache.clear();
        _txnRevision.value++;
        _txnsLoaded = true;
        _settleLoading();
      },
      // Budgets still render (at zero progress) if this fails; the list screens
      // own the user-facing transaction error.
      onError: (_) {
        _txnsLoaded = true;
        _settleLoading();
      },
    );
  }

  bool _budgetsLoaded = false;
  bool _txnsLoaded = false;

  /// Clears [isLoading] only once *both* halves have arrived. Progress is
  /// budgets measured against transactions, so reporting ready on the budgets
  /// stream alone would flash a spent figure of zero.
  void _settleLoading() {
    if (_budgetsLoaded && _txnsLoaded) isLoading.value = false;
  }

  // ── Derived progress ──────────────────────────────────────────────────────

  /// Per-category totals, cached by type and month.
  ///
  /// Without this every budget rescans the whole transaction history, and
  /// `progressFor` runs several times per rebuild across Home, Budgets and
  /// Reports — so the cost was (budgets × transactions) on every frame that
  /// touched a budget. Building the totals once per month turns each budget
  /// into a handful of map lookups.
  final Map<String, Map<String, int>> _totalsCache = {};

  /// Bumped whenever transactions change. Read inside [_monthTotals] so the
  /// computation still registers as an Obx dependency even on a cache hit —
  /// a cache that hides the read would leave the UI stale.
  final RxInt _txnRevision = 0.obs;

  Map<String, int> _monthTotals(String type, DateTime month) {
    final key = '${_txnRevision.value}|$type|${month.year}-${month.month}';
    final cached = _totalsCache[key];
    if (cached != null) return cached;

    final totals = <String, int>{};
    for (final t in _transactions) {
      if (t.type != type) continue;
      if (t.date.year != month.year || t.date.month != month.month) continue;
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    _totalsCache[key] = totals;
    return totals;
  }

  /// Total cents transacted in [month] across every category [budget] covers.
  int _actualCents(BudgetModel budget, DateTime month) {
    final totals = _monthTotals(budget.type, month);
    if (budget.isAllCategories) {
      return totals.values.fold(0, (a, b) => a + b);
    }
    var total = 0;
    for (final category in budget.categories) {
      total += totals[category] ?? 0;
    }
    return total;
  }

  /// Expense budgets for the selected month, tightest first — the ones closest
  /// to (or past) their limit are what the user needs to see.
  List<BudgetProgress> get expenseProgress =>
      progressFor(type: AppConstants.txnExpense, month: selectedMonth.value);

  /// Income targets for the selected month, furthest from target first.
  List<BudgetProgress> get incomeProgress =>
      progressFor(type: AppConstants.txnIncome, month: selectedMonth.value);

  /// Budgets of [type] belonging to [month], paired with that month's actuals.
  ///
  /// Takes an explicit month rather than reading [selectedMonth] so Home can
  /// always report the real current month, however the Budgets screen happens
  /// to be scrolled.
  List<BudgetProgress> progressFor({
    required String type,
    required DateTime month,
  }) {
    final target = BudgetModel.monthOf(month);
    final list = budgets
        .where((b) => b.type == type && b.month == target)
        .map<BudgetProgress>(
            (b) => (budget: b, actualCents: _actualCents(b, target)))
        .toList();
    list.sort((a, b) => ratioOf(b).compareTo(ratioOf(a)));
    return list;
  }

  /// Actual over limit, unclamped so the UI can say "112%".
  double ratioOf(BudgetProgress p) => p.budget.limitCents <= 0
      ? 0
      : p.actualCents / p.budget.limitCents;

  /// Total actually transacted across [list], counting each transaction once.
  ///
  /// Budgets may overlap on a category, so summing their individual actuals
  /// would count the same spending twice in a combined figure. This unions the
  /// covered categories first, then totals — per-budget rows still show their
  /// own full amount, which is what makes each row meaningful on its own.
  int combinedActualCents(List<BudgetProgress> list, DateTime month) {
    if (list.isEmpty) return 0;
    final totals = _monthTotals(list.first.budget.type, month);
    if (list.any((p) => p.budget.isAllCategories)) {
      return totals.values.fold(0, (a, b) => a + b);
    }
    final covered = <String>{};
    for (final p in list) {
      covered.addAll(p.budget.categories);
    }
    var sum = 0;
    for (final category in covered) {
      sum += totals[category] ?? 0;
    }
    return sum;
  }

  /// How many of [list] are over their limit.
  static int overBudgetIn(List<BudgetProgress> list) =>
      list.where((p) => p.actualCents > p.budget.limitCents).length;

  /// Every category of [type], regardless of what's already budgeted.
  static List<String> categoriesOf(String type) =>
      type == AppConstants.txnIncome
          ? AppConstants.incomeCategories
          : AppConstants.expenseCategories;

  // ── Month navigation ──────────────────────────────────────────────────────

  void previousMonth() {
    final m = selectedMonth.value;
    selectedMonth.value = DateTime(m.year, m.month - 1);
  }

  void nextMonth() {
    if (!canGoForward) return;
    final m = selectedMonth.value;
    selectedMonth.value = DateTime(m.year, m.month + 1);
  }

  /// Whether stepping forward lands on a month worth showing.
  bool get canGoForward => selectedMonth.value.isBefore(_furthestMonth);

  /// The current month, or the latest month any budget is planned for —
  /// whichever is later. Without this a budget set up in advance could be
  /// created and then never viewed.
  DateTime get _furthestMonth {
    var furthest = BudgetModel.monthOf(DateTime.now());
    for (final b in budgets) {
      if (b.month.isAfter(furthest)) furthest = b.month;
    }
    return furthest;
  }

  // ── Budget CRUD ───────────────────────────────────────────────────────────
  // Writes are optimistic: local state is committed first, then the Firestore
  // call is handed to SyncService. Nothing user-visible is ever awaited on the
  // network — offline a Firestore write future never completes, so awaiting one
  // would hang the UI indefinitely.

  Future<void> addBudget({
    required String type,
    required List<String> categories,
    required String limitText,
    required DateTime month,
    String name = '',
  }) async {
    final uid = _uid;
    if (uid == null) return;
    if (categories.isEmpty) return;
    final limitCents = parseCents(limitText);
    if (limitCents == null) return;
    final target = BudgetModel.monthOf(month);

    isSaving.value = true;
    try {
      final budget = _budgetRepo.buildBudget(
        type: type,
        categories: categories,
        name: _clamp(name, AppConstants.maxBudgetNameLength),
        limitCents: limitCents,
        month: target,
      );
      budgets.insert(0, budget);
      AppSnackbar.saved('Budget added');
      _sync.enqueue(
        () => _budgetRepo.writeBudget(uid, budget),
        label: 'budget',
        onError: () => budgets.removeWhere((b) => b.id == budget.id),
      );
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> updateBudget({
    required String id,
    required List<String> categories,
    required String limitText,
    String name = '',
  }) async {
    final uid = _uid;
    if (uid == null) return;
    if (categories.isEmpty) return;
    final limitCents = parseCents(limitText);
    if (limitCents == null) return;
    final idx = budgets.indexWhere((b) => b.id == id);
    if (idx == -1) return;

    final original = budgets[idx];
    final updated = original.copyWith(
      categories: categories,
      name: _clamp(name, AppConstants.maxBudgetNameLength),
      limitCents: limitCents,
    );
    budgets[idx] = updated.copyWith(pendingSync: true);
    AppSnackbar.saved('Budget updated');
    _sync.enqueue(
      () => _budgetRepo.updateBudget(uid, updated),
      label: 'budget',
      onError: () => _restoreBudget(id, original),
    );
  }

  Future<void> deleteBudget(String id) async {
    final uid = _uid;
    if (uid == null) return;
    final idx = budgets.indexWhere((b) => b.id == id);
    if (idx == -1) return;
    final removed = budgets[idx];
    budgets.removeAt(idx);
    _sync.enqueue(
      () => _budgetRepo.deleteBudget(uid, id),
      label: 'budget',
      isDelete: true,
      onError: () => budgets.insert(idx.clamp(0, budgets.length), removed),
    );
  }

  /// Puts [original] back where [id] currently sits, rolling back an optimistic
  /// edit the server ultimately rejected.
  void _restoreBudget(String id, BudgetModel original) {
    final idx = budgets.indexWhere((b) => b.id == id);
    if (idx != -1) budgets[idx] = original;
  }

  // ── Goal CRUD ─────────────────────────────────────────────────────────────

  Future<void> addGoal({
    required String title,
    required String targetText,
    String? startingText,
    DateTime? deadline,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    if (title.trim().isEmpty) return;
    final targetCents = parseCents(targetText);
    if (targetCents == null) return;
    final savedCents =
        startingText == null ? 0 : (parseCents(startingText) ?? 0);

    isSaving.value = true;
    try {
      final goal = _goalRepo.buildGoal(
        title: _clamp(title, AppConstants.maxGoalTitleLength),
        targetCents: targetCents,
        savedCents: savedCents,
        deadline: deadline,
      );
      goals.insert(0, goal);
      AppSnackbar.saved('Goal created');
      _sync.enqueue(
        () => _goalRepo.writeGoal(uid, goal),
        label: 'goal',
        onError: () => goals.removeWhere((g) => g.id == goal.id),
      );
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> updateGoal({
    required String id,
    required String title,
    required String targetText,
    DateTime? deadline,
    bool clearDeadline = false,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    if (title.trim().isEmpty) return;
    final targetCents = parseCents(targetText);
    if (targetCents == null) return;
    final idx = goals.indexWhere((g) => g.id == id);
    if (idx == -1) return;

    final original = goals[idx];
    final updated = original.copyWith(
      title: _clamp(title, AppConstants.maxGoalTitleLength),
      targetCents: targetCents,
      deadline: deadline,
      clearDeadline: clearDeadline,
    );
    goals[idx] = updated.copyWith(pendingSync: true);
    AppSnackbar.saved('Goal updated');
    _sync.enqueue(
      () => _goalRepo.updateGoal(uid, updated),
      label: 'goal',
      onError: () => _restoreGoal(id, original),
    );
  }

  /// Adds [amountText] to a goal's saved total. Pass a negative-signed intent
  /// via [withdraw] to take money back out.
  Future<void> contribute({
    required String id,
    required String amountText,
    bool withdraw = false,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final delta = parseCents(amountText);
    if (delta == null) return;
    final idx = goals.indexWhere((g) => g.id == id);
    if (idx == -1) return;

    final original = goals[idx];
    // Never let a withdrawal push the saved total below zero.
    final next = withdraw
        ? (original.savedCents - delta).clamp(0, original.savedCents)
        : original.savedCents + delta;

    goals[idx] = original.copyWith(savedCents: next, pendingSync: true);
    final reached = !original.isComplete && next >= original.targetCents;
    AppSnackbar.saved(
      reached
          ? '🎉 ${original.title} reached!'
          : (withdraw ? 'Withdrawn' : 'Contribution added'),
    );
    _sync.enqueue(
      () => _goalRepo.updateSaved(uid, id, next),
      label: 'goal',
      onError: () => _restoreGoal(id, original),
    );
  }

  Future<void> deleteGoal(String id) async {
    final uid = _uid;
    if (uid == null) return;
    final idx = goals.indexWhere((g) => g.id == id);
    if (idx == -1) return;
    final removed = goals[idx];
    goals.removeAt(idx);
    _sync.enqueue(
      () => _goalRepo.deleteGoal(uid, id),
      label: 'goal',
      isDelete: true,
      onError: () => goals.insert(idx.clamp(0, goals.length), removed),
    );
  }

  void _restoreGoal(String id, GoalModel original) {
    final idx = goals.indexWhere((g) => g.id == id);
    if (idx != -1) goals[idx] = original;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Trims free text and caps its length. The sheets set `maxLength` too, but
  /// that only constrains typing — paste writes straight to the controller, so
  /// the ceiling has to hold here as well.
  static String _clamp(String value, int max) {
    final t = value.trim();
    return t.length <= max ? t : t.substring(0, max);
  }

  /// Parses user input into cents, mirroring `Validators.amount`. Returns null
  /// when the text isn't a positive amount.
  static int? parseCents(String text) {
    final parsed = double.tryParse(text.trim().replaceAll(',', ''));
    if (parsed == null || parsed <= 0 || parsed > 999999999) return null;
    return (parsed * 100).round();
  }
}
