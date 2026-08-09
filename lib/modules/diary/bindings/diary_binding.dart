import 'package:get/get.dart';
import '../../../core/services/speech_service.dart';
import '../../../data/providers/firestore_provider.dart';
import '../../../data/repositories/diary_repository.dart';
import '../controllers/diary_controller.dart';

/// Injects dependencies for the Diary module.
class DiaryBinding extends Bindings {
  @override
  void dependencies() {
    // fenix: true — Home links to the diary and both routes may be disposed by
    // `Get.offNamed`; fenix rebuilds on the next `Get.find` instead of throwing.
    Get.lazyPut<DiaryController>(
      () => DiaryController(
        repo: DiaryRepository(firestore: Get.find<FirestoreProvider>()),
      ),
      fenix: true,
    );
    Get.lazyPut<SpeechService>(() => SpeechService(), fenix: true);
  }
}
