import 'package:get/get.dart';
import '../controllers/sport_controller.dart';

/// Injects dependencies for the Sports module.
class SportBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<SportController>(SportController());
  }
}
