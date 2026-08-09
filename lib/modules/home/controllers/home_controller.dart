import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/home_category_filter_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/sport_reminder_service.dart';
import '../../../data/models/sport_record_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../modules/auth/controllers/auth_controller.dart';

/// Drives the Home screen: balance summary + recent transactions.
class HomeController extends GetxController {
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
  final RxBool isLoading = false.obs;

  StreamSubscription<List<TransactionModel>>? _txnSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sportSub;

  HomeController({
    required TransactionRepository txnRepo,
    required HomeCategoryFilterService categoryFilter,
  })  : _txnRepo = txnRepo,
        _categoryFilter = categoryFilter;

  @override
  void onInit() {
    super.onInit();
    _handlePendingNotification();
    // Re-derive as soon as the category settings change in Profile.
    ever(_categoryFilter.excludedIncome, (_) => _applyCategoryFilter());
    ever(_categoryFilter.excludedExpense, (_) => _applyCategoryFilter());
    final authCtrl = Get.find<AuthController>();
    if (authCtrl.user.value != null) {
      _subscribeToTransactions();
      _subscribeToSports();
    } else {
      ever(authCtrl.user, (user) {
        if (user != null && _txnSub == null) {
          _subscribeToTransactions();
          _subscribeToSports();
        }
      });
    }
  }

  void _handlePendingNotification() {
    final route = NotificationService.pendingRoute;
    if (route == null) return;
    final args = NotificationService.pendingArguments;
    NotificationService.pendingRoute = null;
    NotificationService.pendingArguments = null;
    Future.delayed(Duration.zero, () => Get.toNamed(route, arguments: args));
  }

  @override
  void onClose() {
    _txnSub?.cancel();
    _sportSub?.cancel();
    super.onClose();
  }

  void _subscribeToTransactions() {
    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null) return;
    isLoading.value = true;
    _txnSub = _txnRepo.watchTransactions(uid).listen(
      (txns) {
        transactions.assignAll(txns);
        _applyCategoryFilter();
        isLoading.value = false;
      },
      onError: (_) => isLoading.value = false,
    );
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
    int income = 0;
    int expense = 0;
    for (final t in txns) {
      if (t.date.isBefore(monthStart)) continue;
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    totalIncomeCents.value = income;
    totalExpenseCents.value = expense;
    totalBalanceCents.value = income - expense;
  }

  void _subscribeToSports() {
    final uid = Get.find<AuthController>().user.value?.uid;
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
    final dates = all
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

  List<TransactionModel> get recentTransactions =>
      visibleTransactions.take(5).toList();

  List<SportRecordModel> get recentSportRecords =>
      sportRecords.take(5).toList();
}
