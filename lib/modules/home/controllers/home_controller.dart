import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/mixins/auth_scoped_controller.dart';
import '../../../core/services/home_category_filter_service.dart';
import '../../../core/services/pending_launch.dart';
import '../../../core/services/sport_reminder_service.dart';
import '../../../data/models/sport_record_model.dart';
import '../../../data/models/todo_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/transaction_repository.dart';

/// Drives the Home screen: balance summary, quick entry and recent
/// transactions, plus a one-line glance at open tasks.
class HomeController extends GetxController with AuthScopedController {
  final TransactionRepository _txnRepo;
  final HomeCategoryFilterService _categoryFilter;

  /// Every transaction, unfiltered.
  final RxList<TransactionModel> transactions = <TransactionModel>[].obs;

  /// Transactions in the categories the user kept enabled for Home. Everything
  /// on this screen — totals and the recent list — is derived from these.
  final RxList<TransactionModel> visibleTransactions = <TransactionModel>[].obs;

  final RxList<SportRecordModel> sportRecords = <SportRecordModel>[].obs;
  final RxInt totalBalanceCents = 0.obs;
  final RxInt totalIncomeCents = 0.obs;
  final RxInt totalExpenseCents = 0.obs;
  final RxInt sportStreakDays = 0.obs;

  /// Expenses dated today, among the categories visible on Home.
  final RxInt todaySpentCents = 0.obs;

  /// Tasks not yet completed, soonest due first; undated ones after.
  final RxList<TodoModel> openTodos = <TodoModel>[].obs;

  final RxBool isLoading = false.obs;

  StreamSubscription<List<TransactionModel>>? _txnSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sportSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _todoSub;

  HomeController({
    required TransactionRepository txnRepo,
    required HomeCategoryFilterService categoryFilter,
  }) : _txnRepo = txnRepo,
       _categoryFilter = categoryFilter;

  @override
  void onInit() {
    super.onInit();
    _handlePendingLaunch();
    // Re-derive as soon as the category settings change in Profile.
    ever(_categoryFilter.excludedIncome, (_) => _applyCategoryFilter());
    ever(_categoryFilter.excludedExpense, (_) => _applyCategoryFilter());
    bindToAuth();
  }

  @override
  void onUserBound(String uid) {
    _subscribeToTransactions();
    _subscribeToSports();
    _subscribeToTodos();
  }

  @override
  void onUserUnbound() {
    _txnSub?.cancel();
    _sportSub?.cancel();
    _todoSub?.cancel();
    _txnSub = null;
    _sportSub = null;
    _todoSub = null;
    transactions.clear();
    visibleTransactions.clear();
    sportRecords.clear();
    openTodos.clear();
    totalBalanceCents.value = 0;
    totalIncomeCents.value = 0;
    totalExpenseCents.value = 0;
    todaySpentCents.value = 0;
    sportStreakDays.value = 0;
    isLoading.value = false;
  }

  /// Opens the destination a notification or home-screen widget tap asked
  /// for before the app could navigate (cold start, or while signed out).
  void _handlePendingLaunch() {
    final pending = PendingLaunch.consume();
    if (pending == null) return;
    Future.delayed(
      Duration.zero,
      () => Get.toNamed(pending.route, arguments: pending.arguments),
    );
  }

  void _subscribeToTransactions() {
    final uid = boundUid;
    if (uid == null) return;
    isLoading.value = true;
    _txnSub = _txnRepo.watchTransactions(uid).listen((txns) {
      transactions.assignAll(txns);
      _applyCategoryFilter();
      isLoading.value = false;
    }, onError: (_) => isLoading.value = false);
  }

  /// Drops transactions in categories the user excluded from Home, then
  /// refreshes the totals from what's left.
  void _applyCategoryFilter() {
    final visible = transactions.where(_categoryFilter.includes).toList();
    visibleTransactions.assignAll(visible);
    _recalculate(visible);
  }

  void _recalculate(List<TransactionModel> txns) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final todayStart = DateTime(now.year, now.month, now.day);
    int income = 0;
    int expense = 0;
    int today = 0;
    for (final t in txns) {
      if (t.date.isBefore(monthStart)) continue;
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
        if (!t.date.isBefore(todayStart)) today += t.amount;
      }
    }
    totalIncomeCents.value = income;
    totalExpenseCents.value = expense;
    totalBalanceCents.value = income - expense;
    todaySpentCents.value = today;
  }

  void _subscribeToSports() {
    final uid = boundUid;
    if (uid == null) return;
    _sportSub = FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(uid)
        .collection(AppConstants.colSports)
        .orderBy('date', descending: true)
        .limit(200)
        .snapshots()
        .listen(
          (snap) {
            final all = snap.docs.map(SportRecordModel.fromFirestore).toList();
            sportRecords.assignAll(all);
            _computeSportStreak(all);
          },
          // Without a handler a stream error surfaces as an unhandled async
          // exception. The home screen shows no error UI by design, so this just
          // leaves the last good data on screen.
          onError: (_) => isLoading.value = false,
        );
  }

  void _computeSportStreak(List<SportRecordModel> all) {
    final dates =
        all
            .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final yesterdayOnly = todayOnly.subtract(const Duration(days: 1));

    _sportLoggedToday = dates.contains(todayOnly);

    if (dates.isEmpty) {
      sportStreakDays.value = 0;
      _syncSportReminder();
      return;
    }

    if (dates.first != todayOnly && dates.first != yesterdayOnly) {
      sportStreakDays.value = 0;
      _syncSportReminder();
      return;
    }

    int streak = 1;
    for (var i = 1; i < dates.length; i++) {
      final expected = dates[i - 1].subtract(const Duration(days: 1));
      if (dates[i] == expected) {
        streak++;
      } else {
        break;
      }
    }
    sportStreakDays.value = streak;
    _syncSportReminder();
  }

  /// Streams open tasks for the Home glance line.
  ///
  /// Read here rather than through TodoController: that controller cancels
  /// every task reminder when it is disposed, which Home would trigger each
  /// time the user switches tabs.
  void _subscribeToTodos() {
    final uid = boundUid;
    if (uid == null) return;
    _todoSub = FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(uid)
        .collection(AppConstants.colTodos)
        .where('isCompleted', isEqualTo: false)
        .snapshots()
        .listen(
          (snap) {
            final open = snap.docs.map(TodoModel.fromFirestore).toList()
              ..sort((a, b) {
                final ad = a.dueDate, bd = b.dueDate;
                if (ad == null && bd == null) {
                  return b.createdAt.compareTo(a.createdAt);
                }
                if (ad == null) return 1;
                if (bd == null) return -1;
                return ad.compareTo(bd);
              });
            openTodos.assignAll(open);
          },
          // The glance line is optional; on error it just keeps its last state.
          onError: (_) {},
        );
  }

  /// Whether the user has logged a sport entry for today.
  bool get sportLoggedToday => _sportLoggedToday;
  bool _sportLoggedToday = false;

  /// Keeps the sport streak reminder in sync with the live streak state.
  void _syncSportReminder() {
    SportReminderService.sync(
      hasStreak: sportStreakDays.value > 0,
      loggedToday: _sportLoggedToday,
    );
  }

  /// The latest transactions grouped by calendar day, newest day first, each
  /// with the day's spending total.
  List<({DateTime day, List<TransactionModel> txns, int spentCents})>
  get recentByDay {
    final groups =
        <({DateTime day, List<TransactionModel> txns, int spentCents})>[];
    for (final t in visibleTransactions.take(8)) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (groups.isEmpty || groups.last.day != day) {
        groups.add((day: day, txns: [], spentCents: 0));
      }
      groups.last.txns.add(t);
    }
    return [
      for (final g in groups)
        (
          day: g.day,
          txns: g.txns,
          spentCents: g.txns
              .where((t) => !t.isIncome)
              .fold(0, (a, t) => a + t.amount),
        ),
    ];
  }
}
