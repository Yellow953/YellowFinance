import 'package:get/get.dart';
import '../../../data/providers/firestore_provider.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../budgets/bindings/budget_binding.dart';
import '../../diary/bindings/diary_binding.dart';
import '../controllers/reports_controller.dart';

/// Injects dependencies for the Reports module.
class ReportsBinding extends Bindings {
  @override
  void dependencies() {
    // Reports charts budget, goal and diary data. Both controllers already
    // stream it and accept an explicit month, so they are reused through their
    // own bindings rather than duplicating the queries here.
    BudgetBinding().dependencies();
    DiaryBinding().dependencies();

    Get.lazyPut<ReportsController>(
      () => ReportsController(
        txnRepo: TransactionRepository(
          firestore: Get.find<FirestoreProvider>(),
        ),
      ),
    );
  }
}
