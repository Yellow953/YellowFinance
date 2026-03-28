import 'package:get/get.dart';
import '../../../data/providers/firestore_provider.dart';
import '../../../data/repositories/ai_repository.dart';
import '../controllers/ai_controller.dart';

/// Injects dependencies for the AI module.
class AiBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AiController>(
      () => AiController(
        aiRepo: AiRepository(
          firestore: Get.find<FirestoreProvider>(),
        ),
      ),
    );
  }
}
