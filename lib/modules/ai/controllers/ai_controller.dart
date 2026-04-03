import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/utils/app_snackbar.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/ai_message_model.dart';
import '../../auth/controllers/auth_controller.dart';

/// Manages the AI chat session.
class AiController extends GetxController {
  final _uuid = const Uuid();

  final RxList<AiMessageModel> messages = <AiMessageModel>[].obs;
  final RxBool isThinking = false.obs;

  AiController();

  /// Sends a user message and fetches the AI response via Firebase Function.
  Future<void> sendMessage(String content, {String analysisType = 'general'}) =>
      _sendWithPayload(content, analysisType: analysisType);

  /// Fires a pre-built quick analysis prompt.
  ///
  /// [type] is one of: `spending_comparison`, `market_analysis`.
  Future<void> sendQuickAnalysis(String type) {
    final prompts = {
      'spending_comparison':
          'Analyze my spending this month vs last month. Where am I spending more? What can I optimize?',
      'market_analysis':
          'What is the single best asset to buy this month? Give me one specific pick with your reasoning.',
    };
    final prompt = prompts[type] ?? '';
    return sendMessage(prompt, analysisType: type);
  }

  /// Sends an asset analysis with hidden chart context.
  ///
  /// [displayPrompt] is shown in the chat bubble.
  /// [assetContext] is the chart data summary sent as hidden context to the function.
  Future<void> sendAssetAnalysis(String displayPrompt, String assetContext) {
    return _sendWithPayload(
      displayPrompt,
      analysisType: 'asset_analysis',
      extra: {'assetContext': assetContext},
    );
  }

  /// Internal helper that accepts extra fields for the callable payload.
  Future<void> _sendWithPayload(
    String content, {
    String analysisType = 'general',
    Map<String, dynamic> extra = const {},
  }) async {
    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null || content.trim().isEmpty || isThinking.value) return;
    if (!Get.find<ConnectivityService>().isOnline.value) {
      AppSnackbar.error('No internet connection.');
      return;
    }

    final userMsg = AiMessageModel(
      id: _uuid.v4(),
      role: 'user',
      content: content.trim(),
      timestamp: DateTime.now(),
    );

    // Snapshot history BEFORE adding the current message.
    final history = messages
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    messages.add(userMsg);
    isThinking.value = true;

    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      final callable =
          FirebaseFunctions.instance.httpsCallable('analyzeFinances');
      final result = await callable.call<Map<String, dynamic>>({
        'userId': uid,
        'prompt': content.trim(),
        'analysisType': analysisType,
        'history': history,
        ...extra,
      });

      final responseText =
          result.data['response'] as String? ?? 'No response received.';

      messages.add(AiMessageModel(
        id: _uuid.v4(),
        role: 'assistant',
        content: responseText,
        timestamp: DateTime.now(),
      ));

    } catch (e) {
      debugPrint('AiController._sendWithPayload error: $e');
      messages.add(AiMessageModel(
        id: _uuid.v4(),
        role: 'assistant',
        content: 'Sorry, I couldn\'t process your request. Please try again.',
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
