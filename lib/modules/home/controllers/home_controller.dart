import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/sport_record_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../modules/auth/controllers/auth_controller.dart';

/// Drives the Home screen: balance summary + recent transactions.
class HomeController extends GetxController {
  final TransactionRepository _txnRepo;

  final RxList<TransactionModel> transactions = <TransactionModel>[].obs;
  final RxList<SportRecordModel> sportRecords = <SportRecordModel>[].obs;
  final RxInt totalBalanceCents = 0.obs;
  final RxInt totalIncomeCents = 0.obs;
  final RxInt totalExpenseCents = 0.obs;
  final RxInt sportStreakDays = 0.obs;
  final RxBool isLoading = false.obs;

  StreamSubscription<List<TransactionModel>>? _txnSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sportSub;

  HomeController({required TransactionRepository txnRepo})
      : _txnRepo = txnRepo;

  @override
  void onInit() {
    super.onInit();
    _handlePendingNotification();
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
    NotificationService.pendingRoute = null;
    Future.delayed(Duration.zero, () => Get.toNamed(route));
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
        _recalculate(txns);
        isLoading.value = false;
      },
      onError: (_) => isLoading.value = false,
    );
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
        .collection('users')
        .doc(uid)
        .collection('sports')
        .orderBy('date', descending: true)
        .limit(200)
        .snapshots()
        .listen((snap) {
      final all = snap.docs.map(SportRecordModel.fromFirestore).toList();
      sportRecords.assignAll(all);
      _computeSportStreak(all);
    });
  }

  void _computeSportStreak(List<SportRecordModel> all) {
    final dates = all
        .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (dates.isEmpty) {
      sportStreakDays.value = 0;
      return;
    }

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final yesterdayOnly = todayOnly.subtract(const Duration(days: 1));

    if (dates.first != todayOnly && dates.first != yesterdayOnly) {
      sportStreakDays.value = 0;
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
  }

  List<TransactionModel> get recentTransactions =>
      transactions.take(5).toList();

  List<SportRecordModel> get recentSportRecords =>
      sportRecords.take(5).toList();
}
