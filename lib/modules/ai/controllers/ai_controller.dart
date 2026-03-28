import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/utils/app_snackbar.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/ai_message_model.dart';
import '../../../data/repositories/ai_repository.dart';
import '../../auth/controllers/auth_controller.dart';

/// Manages the AI chat session.
class AiController extends GetxController {
  final AiRepository _aiRepo;
  final _uuid = const Uuid();

  final RxList<AiMessageModel> messages = <AiMessageModel>[].obs;
  final RxBool isThinking = false.obs;
  final RxBool canSend = true.obs;

  AiController({required AiRepository aiRepo}) : _aiRepo = aiRepo;

  @override
  void onInit() {
    super.onInit();
    _checkRateLimit();
  }

  Future<void> _checkRateLimit() async {
    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null) return;
    canSend.value = await _aiRepo.canMakeAiCall(uid);
  }

  /// Sends a user message and fetches the AI response via Firebase Function.
  Future<void> sendMessage(String content) async {
    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null || content.trim().isEmpty) return;
    if (!canSend.value) {
      AppSnackbar.show('Limit reached',
          'You\'ve used all 20 AI calls for today. Try again tomorrow.');
      return;
    }

    final userMsg = AiMessageModel(
      id: _uuid.v4(),
      role: 'user',
      content: content.trim(),
      timestamp: DateTime.now(),
    );
    messages.add(userMsg);
    isThinking.value = true;

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('analyzeFinances');
      final result = await callable.call<Map<String, dynamic>>({
        'userId': uid,
        'prompt': content.trim(),
      });
      final responseText =
          result.data['response'] as String? ?? 'No response received.';

      messages.add(AiMessageModel(
        id: _uuid.v4(),
        role: 'assistant',
        content: responseText,
        timestamp: DateTime.now(),
      ));

      // Save conversation for rate-limit tracking
      await _aiRepo.saveConversation(uid, messages.toList());
      canSend.value = await _aiRepo.canMakeAiCall(uid);
    } catch (e) {
      messages.add(AiMessageModel(
        id: _uuid.v4(),
        role: 'assistant',
        content:
            'Sorry, I couldn\'t process your request. Please try again.',
        timestamp: DateTime.now(),
      ));
    } finally {
      isThinking.value = false;
    }
  }

  void clearConversation() {
    messages.clear();
  }
}
