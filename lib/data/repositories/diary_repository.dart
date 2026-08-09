import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/diary_entry_model.dart';
import '../providers/firestore_provider.dart';

/// CRUD operations for diary entries.
class DiaryRepository {
  final FirestoreProvider _firestore;
  final _uuid = const Uuid();

  DiaryRepository({required FirestoreProvider firestore})
      : _firestore = firestore;

  /// Streams every entry for [uid], most recent day first.
  ///
  /// `includeMetadataChanges` is required so the stream re-emits when a write
  /// is acknowledged — see [BudgetRepository.watchBudgets].
  Stream<List<DiaryEntryModel>> watchEntries(String uid) => _firestore
      .diaryCollection(uid)
      .orderBy('date', descending: true)
      .snapshots(includeMetadataChanges: true)
      .map((snap) => snap.docs.map(DiaryEntryModel.fromFirestore).toList());

  /// Builds an entry with a fresh ID without touching Firestore, so the caller
  /// can commit it locally and hand the write to `SyncService`.
  DiaryEntryModel buildEntry({
    required String title,
    required String body,
    required Mood mood,
    required DateTime date,
    bool hasVoice = false,
  }) {
    final now = DateTime.now();
    return DiaryEntryModel(
      id: _uuid.v4(),
      title: title,
      body: body,
      mood: mood,
      date: date,
      createdAt: now,
      updatedAt: now,
      hasVoice: hasVoice,
      pendingSync: true,
    );
  }

  /// Persists [entry]. Offline this queues to disk and replays on reconnect.
  Future<void> writeEntry(String uid, DiaryEntryModel entry) =>
      _firestore.diaryCollection(uid).doc(entry.id).set(entry.toFirestore());

  /// Overwrites the editable fields of an existing entry.
  Future<void> updateEntry(String uid, DiaryEntryModel entry) =>
      _firestore.diaryCollection(uid).doc(entry.id).update({
        'title': entry.title,
        'body': entry.body,
        'mood': entry.mood.name,
        'date': Timestamp.fromDate(entry.date),
        'updatedAt': Timestamp.fromDate(entry.updatedAt),
        'hasVoice': entry.hasVoice,
      });

  Future<void> deleteEntry(String uid, String entryId) =>
      _firestore.diaryCollection(uid).doc(entryId).delete();
}
