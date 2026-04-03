import '../providers/firestore_provider.dart';

/// Handles AI chat interactions via Firebase Callable Functions.
class AiRepository {
  final FirestoreProvider _firestore;

  AiRepository({required FirestoreProvider firestore}) : _firestore = firestore;
}
