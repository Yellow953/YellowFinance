import 'package:get/get.dart';
import '../../../data/providers/firestore_provider.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../controllers/reports_controller.dart';

/// Injects dependencies for the Reports module.
class ReportsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReportsController>(
      () => ReportsController(
        txnRepo: TransactionRepository(
          firestore: Get.find<FirestoreProvider>(),
        ),
      ),
    );
  }
}
