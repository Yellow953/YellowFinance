import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
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

  /// Records an AI call to Firestore for rate limiting purposes.
  Future<void> recordAiCall(String uid) async {
    await _firestore.aiConversationsCollection(uid).add({
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Checks if the user is within the daily AI call limit.
  Future<bool> canMakeAiCall(String uid) async {
    final count = await fetchTodayCallCount(uid);
    return count < AppConstants.aiDailyLimit;
  }
}
