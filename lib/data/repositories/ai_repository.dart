import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../models/ai_message_model.dart';
import '../providers/firestore_provider.dart';

/// Handles AI chat interactions via Firebase Callable Functions.
class AiRepository {
  final FirestoreProvider _firestore;

  AiRepository({
    required FirestoreProvider firestore,
  }) : _firestore = firestore;

  /// Returns how many AI calls the user has made today.
  Future<int> fetchTodayCallCount(String uid) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final snap = await _firestore
        .aiConversationsCollection(uid)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();
    return snap.docs.length;
  }

  /// Saves a conversation record to Firestore (for rate limiting).
  Future<void> saveConversation(
      String uid, List<AiMessageModel> messages) async {
    await _firestore.aiConversationsCollection(uid).add({
      'messages': messages.map((m) => m.toMap()).toList(),
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Fetches all conversations for the user.
  Future<List<Map<String, dynamic>>> fetchConversations(String uid) async {
    final snap = await _firestore
        .aiConversationsCollection(uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Checks if the user is within the daily AI call limit.
  Future<bool> canMakeAiCall(String uid) async {
    final count = await fetchTodayCallCount(uid);
    return count < AppConstants.aiDailyLimit;
  }
}
