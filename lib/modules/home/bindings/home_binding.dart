import 'package:get/get.dart';
import '../../../core/services/home_category_filter_service.dart';
import '../../../data/providers/firestore_provider.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../controllers/home_controller.dart';

/// Injects dependencies for the Home module.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
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
