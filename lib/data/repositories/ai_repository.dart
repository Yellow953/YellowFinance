import '../providers/firestore_provider.dart';

/// Handles AI chat interactions via Firebase Callable Functions.
class AiRepository {
  // ignore: unused_field — placeholder until AI callable functions are wired up
  final FirestoreProvider _firestore;

  AiRepository({required FirestoreProvider firestore}) : _firestore = firestore;
}
