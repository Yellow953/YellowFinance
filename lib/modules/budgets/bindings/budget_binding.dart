import 'package:get/get.dart';
import '../../../data/providers/firestore_provider.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../controllers/budget_controller.dart';

/// Injects dependencies for the Budgets & Goals module.
///
/// `fenix: true` because Home also depends on this controller for its summary
/// card: navigating away with `Get.offNamed` disposes it, and fenix rebuilds it
/// on the next `Get.find` instead of throwing.
class BudgetBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BudgetController>(
      () => BudgetController(
        budgetRepo: BudgetRepository(firestore: Get.find<FirestoreProvider>()),
        goalRepo: GoalRepository(firestore: Get.find<FirestoreProvider>()),
        txnRepo: TransactionRepository(
          firestore: Get.find<FirestoreProvider>(),
        ),
      ),
      fenix: true,
    );
  }
}
