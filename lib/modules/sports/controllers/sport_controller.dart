import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/models/sport_record_model.dart';
import '../../auth/controllers/auth_controller.dart';

/// Manages the sports records list and add-record form state.
class SportController extends GetxController {
  final RxList<SportRecordModel> records = <SportRecordModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  /// Month currently displayed. Defaults to current month.
  final Rx<DateTime> selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month).obs;

  /// Category filter: 'All' or a specific category name.
  final RxString filterCategory = 'All'.obs;

  // Cached computed values — recomputed only when inputs change
  final Rx<List<SportRecordModel>> _filteredRecords =
      Rx<List<SportRecordModel>>([]);
  final Rx<List<({DateTime date, List<SportRecordModel> records})>>
      _filteredByDay =
      Rx<List<({DateTime date, List<SportRecordModel> records})>>([]);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _subscribe();
    ever(records, (_) => _recompute());
    ever(selectedMonth, (_) => _recompute());
    ever(filterCategory, (_) => _recompute());
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  String? get _uid => Get.find<AuthController>().user.value?.uid;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('sports');

  // ── Stream ────────────────────────────────────────────────────────────────

  void _subscribe() {
    final uid = _uid;
    if (uid == null) return;
    isLoading.value = true;
    _sub = _col(uid)
        .orderBy('date', descending: true)
        .limit(200)
        .snapshots()
        .listen(
      (snap) {
        records.assignAll(snap.docs.map(SportRecordModel.fromFirestore));
        isLoading.value = false;
      },
      onError: (_) {
        AppSnackbar.error('Could not load records.');
        isLoading.value = false;
      },
    );
  }

  // ── Recompute cache ───────────────────────────────────────────────────────

  void _recompute() {
    final m = selectedMonth.value;
    final cat = filterCategory.value;

    final filtered = records.where((r) {
      final inMonth = r.date.year == m.year && r.date.month == m.month;
      final inCat = cat == 'All' || r.category == cat;
      return inMonth && inCat;
    }).toList();
    _filteredRecords.value = filtered;

    // Group by day
    final grouped = <String, List<SportRecordModel>>{};
    for (final r in filtered) {
      final key =
          '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}';
      (grouped[key] ??= []).add(r);
    }
    _filteredByDay.value = grouped.entries.map((e) {
      final parts = e.key.split('-');
      return (
        date: DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
        records: e.value
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // ── Public getters reading cached Rx values ───────────────────────────────

  List<SportRecordModel> get filteredRecords => _filteredRecords.value;

  List<({DateTime date, List<SportRecordModel> records})> get filteredByDay =>
      _filteredByDay.value;

  // ── Month navigation ──────────────────────────────────────────────────────

  void previousMonth() {
    final m = selectedMonth.value;
    selectedMonth.value = DateTime(m.year, m.month - 1);
    filterCategory.value = 'All';
  }

  void nextMonth() {
    final m = selectedMonth.value;
    final next = DateTime(m.year, m.month + 1);
    final now = DateTime.now();
    if (!next.isAfter(DateTime(now.year, now.month))) {
      selectedMonth.value = next;
      filterCategory.value = 'All';
    }
  }

  bool get canGoToNextMonth {
    final now = DateTime.now();
    final next =
        DateTime(selectedMonth.value.year, selectedMonth.value.month + 1);
    return !next.isAfter(DateTime(now.year, now.month));
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> addRecord({
    required DateTime date,
    required String category,
    required String description,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    if (description.trim().isEmpty && category.isEmpty) return;

    isSaving.value = true;
    try {
      final ref = _col(uid).doc();
      final record = SportRecordModel(
        id: ref.id,
        date: DateTime(date.year, date.month, date.day),
        category: category,
        description: description.trim(),
        createdAt: DateTime.now(),
      );
      records.insert(0, record);
      await ref.set(record.toFirestore());
      AppSnackbar.success('Record added');
    } catch (_) {
      AppSnackbar.error('Could not save record.');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteRecord(String id) async {
    final uid = _uid;
    if (uid == null) return;
    records.removeWhere((r) => r.id == id);
    try {
      await _col(uid).doc(id).delete();
    } catch (_) {
      AppSnackbar.error('Could not delete record.');
    }
  }
}
