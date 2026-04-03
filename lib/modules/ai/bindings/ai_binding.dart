import 'package:get/get.dart';
import '../controllers/ai_controller.dart';

/// Injects dependencies for the AI module.
class AiBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AiController>(() => AiController());
  }
}
