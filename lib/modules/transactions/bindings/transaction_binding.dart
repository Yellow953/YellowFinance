import 'package:get/get.dart';
import '../../../data/providers/firestore_provider.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../controllers/transaction_controller.dart';

/// Injects dependencies for the Transactions module.
class TransactionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TransactionController>(
      () => TransactionController(
        txnRepo: TransactionRepository(
          firestore: Get.find<FirestoreProvider>(),
        ),
      ),
    );
  }
}
