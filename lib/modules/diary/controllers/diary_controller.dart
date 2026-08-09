import 'dart:async';

import 'package:get/get.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/models/diary_entry_model.dart';
import '../../../data/repositories/diary_repository.dart';
import '../../auth/controllers/auth_controller.dart';

/// A day's worth of entries, for the grouped list.
typedef DiaryDay = ({DateTime date, List<DiaryEntryModel> entries});

/// Drives the diary list: streaming, search and CRUD.
class DiaryController extends GetxController {
  final DiaryRepository _repo;

  final RxList<DiaryEntryModel> entries = <DiaryEntryModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  /// Free-text search across title and body.
  final RxString query = ''.obs;

  /// Moods to include. Empty means "any mood" — a set rather than a single
  /// value so "show me the bad days" can span Low and Bad together.
  final RxSet<Mood> moodFilter = <Mood>{}.obs;

  /// Inclusive entry-date bounds. Null means unbounded on that end.
  final Rx<DateTime?> fromDate = Rx<DateTime?>(null);
  final Rx<DateTime?> toDate = Rx<DateTime?>(null);

  /// Sort order: newest first by default.
  final RxBool oldestFirst = false.obs;

  /// Whether anything is narrowing the list — drives the filter button's dot
  /// and the "clear" affordance.
  bool get hasActiveFilters =>
      query.value.trim().isNotEmpty ||
      moodFilter.isNotEmpty ||
      fromDate.value != null ||
      toDate.value != null ||
      oldestFirst.value;

  /// How many filters are on, for the button badge. Search is excluded — it has
  /// its own visible field.
  int get activeFilterCount =>
      (moodFilter.isNotEmpty ? 1 : 0) +
      (fromDate.value != null || toDate.value != null ? 1 : 0) +
      (oldestFirst.value ? 1 : 0);

  void clearFilters() {
    query.value = '';
    moodFilter.clear();
    fromDate.value = null;
    toDate.value = null;
    oldestFirst.value = false;
  }

  void toggleMood(Mood mood) {
    if (!moodFilter.remove(mood)) moodFilter.add(mood);
  }

  StreamSubscription<List<DiaryEntryModel>>? _sub;

  DiaryController({required DiaryRepository repo}) : _repo = repo;

  @override
  void onInit() {
    super.onInit();
    // Keep the global sync indicator in step with what's actually unsynced.
    ever(entries, (List<DiaryEntryModel> list) {
      _sync.reportPending('diary', list.where((e) => e.pendingSync).length);
    });
    final authCtrl = Get.find<AuthController>();
    if (authCtrl.user.value != null) {
      _subscribe();
    } else {
      ever(authCtrl.user, (user) {
        if (user != null && _sub == null) _subscribe();
      });
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    _sync.reportPending('diary', 0);
    super.onClose();
  }

  String? get _uid => Get.find<AuthController>().user.value?.uid;

  SyncService get _sync => Get.find<SyncService>();

  void _subscribe() {
    final uid = _uid;
    if (uid == null) return;
    isLoading.value = true;
    _sub = _repo.watchEntries(uid).listen(
      (list) {
        entries.assignAll(list);
        isLoading.value = false;
      },
      onError: (_) {
        AppSnackbar.error('Could not load your diary.');
        isLoading.value = false;
      },
    );
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  /// Entries matching the current search text and mood filter.
  ///
  /// Filtering is done in memory rather than in the query: Firestore can't do
  /// substring search, and a personal diary is small enough that the whole
  /// collection is already streamed for offline use.
  List<DiaryEntryModel> get filteredEntries {
    final q = query.value.trim().toLowerCase();
    final moods = moodFilter;
    final from = fromDate.value;
    final to = toDate.value;

    final result = entries.where((e) {
      if (moods.isNotEmpty && !moods.contains(e.mood)) return false;
      // Compare on day boundaries so a range is inclusive of both ends
      // regardless of the time of day an entry carries.
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      if (from != null && day.isBefore(from)) return false;
      if (to != null && day.isAfter(to)) return false;
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          e.body.toLowerCase().contains(q);
    }).toList();

    return result;
  }

  /// [filteredEntries] grouped by day, newest day first and newest entry first
  /// within each day.
  List<DiaryDay> get entriesByDay {
    final grouped = <DateTime, List<DiaryEntryModel>>{};
    for (final e in filteredEntries) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      grouped.putIfAbsent(day, () => []).add(e);
    }
    final days = grouped.keys.toList()
      ..sort((a, b) => oldestFirst.value ? a.compareTo(b) : b.compareTo(a));
    return [
      for (final d in days)
        (
          date: d,
          entries: grouped[d]!
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        ),
    ];
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────
  // Writes are optimistic: local state is committed first, then the Firestore
  // call is handed to SyncService. Nothing user-visible is ever awaited on the
  // network — offline a Firestore write future never completes, so awaiting one
  // would hang the UI indefinitely.

  Future<void> addEntry({
    required String title,
    required String body,
    Mood mood = Mood.none,
    DateTime? date,
    bool hasVoice = false,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    if (title.trim().isEmpty && body.trim().isEmpty) return;

    isSaving.value = true;
    try {
      final entry = _repo.buildEntry(
        title: _clampTitle(title),
        body: _clampBody(body),
        mood: mood,
        date: date ?? DateTime.now(),
        hasVoice: hasVoice,
      );
      entries.insert(0, entry);
      AppSnackbar.saved('Entry saved');
      _sync.enqueue(
        () => _repo.writeEntry(uid, entry),
        label: 'diary entry',
        onError: () => entries.removeWhere((e) => e.id == entry.id),
      );
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> updateEntry({
    required String id,
    required String title,
    required String body,
    Mood mood = Mood.none,
    DateTime? date,
    bool hasVoice = false,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final idx = entries.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    isSaving.value = true;
    final original = entries[idx];
    final updated = original.copyWith(
      title: _clampTitle(title),
      body: _clampBody(body),
      mood: mood,
      date: date ?? original.date,
      updatedAt: DateTime.now(),
      // Sticky: an entry that was ever dictated keeps its marker.
      hasVoice: original.hasVoice || hasVoice,
    );
    entries[idx] = updated.copyWith(pendingSync: true);
    isSaving.value = false;
    AppSnackbar.saved('Entry updated');
    _sync.enqueue(
      () => _repo.updateEntry(uid, updated),
      label: 'diary entry',
      onError: () => _restore(id, original),
    );
  }

  Future<void> deleteEntry(String id) async {
    final uid = _uid;
    if (uid == null) return;
    final idx = entries.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final removed = entries[idx];
    entries.removeAt(idx);
    _sync.enqueue(
      () => _repo.deleteEntry(uid, id),
      label: 'diary entry',
      isDelete: true,
      onError: () => entries.insert(idx.clamp(0, entries.length), removed),
    );
  }

  /// Trims and caps free text. The editor also sets `maxLength`, but that only
  /// constrains typing — dictation and paste both write straight to the
  /// controller, so the ceiling has to be enforced here too.
  String _clampTitle(String value) {
    final t = value.trim();
    return t.length <= AppConstants.maxDiaryTitleLength
        ? t
        : t.substring(0, AppConstants.maxDiaryTitleLength);
  }

  String _clampBody(String value) {
    final t = value.trim();
    return t.length <= AppConstants.maxDiaryBodyLength
        ? t
        : t.substring(0, AppConstants.maxDiaryBodyLength);
  }

  void _restore(String id, DiaryEntryModel original) {
    final idx = entries.indexWhere((e) => e.id == id);
    if (idx != -1) entries[idx] = original;
  }
}
