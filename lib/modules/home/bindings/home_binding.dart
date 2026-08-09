import 'package:get/get.dart';
import '../../../core/services/home_category_filter_service.dart';
import '../../../data/providers/firestore_provider.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../budgets/bindings/budget_binding.dart';
import '../controllers/home_controller.dart';

/// Injects dependencies for the Home module.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Home shows a budget summary card, so it needs the same controller the
    // Budgets screen uses. Registered through that module's binding rather than
    // duplicated here, so the two can never drift apart.
    BudgetBinding().dependencies();

    Get.lazyPut<HomeController>(
      () => HomeController(
        txnRepo: TransactionRepository(
          firestore: Get.find<FirestoreProvider>(),
        ),
        categoryFilter: Get.find<HomeCategoryFilterService>(),
      ),
    );
  }
}
