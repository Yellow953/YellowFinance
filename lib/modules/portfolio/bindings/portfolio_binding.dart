import 'package:get/get.dart';
import '../../../data/providers/firestore_provider.dart';
import '../../../data/repositories/portfolio_repository.dart';
import '../controllers/portfolio_controller.dart';

/// Injects dependencies for the Portfolio module.
class PortfolioBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PortfolioController>(
      () => PortfolioController(
        portfolioRepo: PortfolioRepository(
          firestore: Get.find<FirestoreProvider>(),
        ),
      ),
    );
  }
}
