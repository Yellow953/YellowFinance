import 'dart:async';
import 'package:get/get.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../modules/auth/controllers/auth_controller.dart';

/// Drives the Home screen: balance summary + recent transactions.
class HomeController extends GetxController {
  final TransactionRepository _txnRepo;

  final RxList<TransactionModel> transactions = <TransactionModel>[].obs;
  final RxInt totalBalanceCents = 0.obs;
  final RxInt totalIncomeCents = 0.obs;
  final RxInt totalExpenseCents = 0.obs;
  final RxBool isLoading = false.obs;

  StreamSubscription<List<TransactionModel>>? _txnSub;

  HomeController({required TransactionRepository txnRepo})
      : _txnRepo = txnRepo;

  @override
  void onInit() {
    super.onInit();
    _subscribeToTransactions();
    _handlePendingNotification();
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
    int income = 0;
    int expense = 0;
    for (final t in txns) {
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

  List<TransactionModel> get recentTransactions =>
      transactions.take(5).toList();
}
