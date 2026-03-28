import 'package:get/get.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/providers/firestore_provider.dart';
import '../../../data/repositories/auth_repository.dart';
import '../controllers/auth_controller.dart';

/// Injects dependencies for the auth module.
class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthController>(
      () => AuthController(
        authRepo: AuthRepository(
          authService: Get.find<AuthService>(),
          firestore: Get.find<FirestoreProvider>(),
        ),
      ),
    );
  }
}
