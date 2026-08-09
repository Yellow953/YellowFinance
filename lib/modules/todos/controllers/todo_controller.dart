import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/models/todo_model.dart';
import '../../auth/controllers/auth_controller.dart';

DateTime _nextOccurrence(DateTime current, Recurrence recurrence) {
  switch (recurrence) {
    case Recurrence.daily:
      return current.add(const Duration(days: 1));
    case Recurrence.weekly:
      return current.add(const Duration(days: 7));
    case Recurrence.monthly:
      var month = current.month + 1;
      var year = current.year;
      if (month > 12) {
        month = 1;
        year++;
      }
      final lastDay = DateTime(year, month + 1, 0).day;
      return DateTime(
        year,
        month,
        current.day.clamp(1, lastDay),
        current.hour,
        current.minute,
      );
    case Recurrence.none:
      return current;
  }
}

/// Manages the todos list and add/edit form state.
class TodoController extends GetxController {
  final RxList<TodoModel> todos = <TodoModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  /// Filter: 'All' | 'Today' | 'Upcoming' | 'Done'
  final RxString filter = 'All'.obs;

  static const filters = ['All', 'Today', 'Upcoming', 'Done'];

  /// View mode: 'list' | 'calendar'
  final RxString viewMode = 'list'.obs;

  /// Month currently shown in the calendar (normalized to the 1st, midnight).
  late final Rx<DateTime> focusedMonth;

  /// Day selected in the calendar (normalized to midnight).
  late final Rx<DateTime> selectedDay;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  bool _rescheduled = false;

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    focusedMonth = DateTime(now.year, now.month).obs;
    selectedDay = DateTime(now.year, now.month, now.day).obs;
    // Keep the global sync indicator in step with what's actually unsynced.
    ever(todos, (List<TodoModel> list) {
      _sync.reportPending('tasks', list.where((t) => t.pendingSync).length);
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
    _sync.reportPending('tasks', 0);
    super.onClose();
  }

  String? get _uid => Get.find<AuthController>().user.value?.uid;

  SyncService get _sync => Get.find<SyncService>();

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection(AppConstants.colUsers)
          .doc(uid)
          .collection(AppConstants.colTodos);

  // ── Stream subscription ───────────────────────────────────────────────────
  // snapshots() serves from Firestore's local cache immediately, then updates
  // from the server — giving a fast first paint and full offline support.

  void _subscribe() {
    final uid = _uid;
    if (uid == null) return;
    isLoading.value = true;
    _sub = _col(uid)
        .orderBy('createdAt', descending: true)
        // includeMetadataChanges: pendingSync reads hasPendingWrites, and a
        // server acknowledgement changes only that metadata. Without it the
        // stream never re-emits on ack and the "Syncing…" banner sticks.
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snap) {
        todos.assignAll(snap.docs.map(TodoModel.fromFirestore));
        isLoading.value = false;
        // On first load, re-register any notifications that were lost
        // (e.g. app data cleared). Boot-receiver handles normal reboots.
        if (!_rescheduled) {
          _rescheduled = true;
          NotificationService.rescheduleAll(todos.toList());
        }
      },
      onError: (_) {
        AppSnackbar.error('Could not load tasks.');
        isLoading.value = false;
      },
    );
  }

  @override
  Future<void> refresh() async {
    // The stream keeps itself up to date; a manual refresh just re-fetches
    // from the server to ensure we're not stuck on stale cache.
    final uid = _uid;
    if (uid == null) return;
    // Offline there is nothing to re-fetch — the stream already holds the
    // cache and a Source.server read could only throw.
    if (!Get.find<ConnectivityService>().isOnline.value) return;
    try {
      final snap = await _col(uid)
          .orderBy('createdAt', descending: true)
          .get(const GetOptions(source: Source.server));
      todos.assignAll(snap.docs.map(TodoModel.fromFirestore));
    } catch (_) {
      // Already online via the stream; silently ignore pull-to-refresh errors.
    }
  }

  // ── Filtered list ─────────────────────────────────────────────────────────

  List<TodoModel> get filteredTodos {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (filter.value) {
      case 'Today':
        return todos.where((t) {
          if (t.isCompleted) return false;
          if (t.dueDate == null) return false;
          final d = t.dueDate!;
          return DateTime(d.year, d.month, d.day) == today;
        }).toList();
      case 'Upcoming':
        return todos.where((t) {
          if (t.isCompleted) return false;
          if (t.dueDate == null) return true;
          final d = t.dueDate!;
          return DateTime(d.year, d.month, d.day).isAfter(today);
        }).toList();
      case 'Done':
        return todos.where((t) => t.isCompleted).toList();
      default: // All — excludes completed tasks (use 'Done' tab to see those)
        return todos.where((t) => !t.isCompleted).toList();
    }
  }

  // ── Calendar helpers ──────────────────────────────────────────────────────

  /// Tasks with a due date falling on [day], earliest first.
  List<TodoModel> todosForDay(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    return todos.where((t) {
      if (t.dueDate == null) return false;
      final d = t.dueDate!;
      return DateTime(d.year, d.month, d.day) == target;
    }).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  /// Whether any task is due on [day] (drives the calendar dot markers).
  bool hasTasksOn(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    return todos.any((t) {
      if (t.dueDate == null) return false;
      final d = t.dueDate!;
      return DateTime(d.year, d.month, d.day) == target;
    });
  }

  void goToPreviousMonth() {
    final m = focusedMonth.value;
    focusedMonth.value = DateTime(m.year, m.month - 1);
  }

  void goToNextMonth() {
    final m = focusedMonth.value;
    focusedMonth.value = DateTime(m.year, m.month + 1);
  }

  void selectDay(DateTime day) {
    selectedDay.value = DateTime(day.year, day.month, day.day);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────
  // Writes are optimistic: local state and notifications are committed first,
  // then the Firestore call is handed to SyncService. Nothing user-visible is
  // ever awaited on the network — offline a Firestore write future never
  // completes, so awaiting one would hang the UI indefinitely.

  Future<void> addTodo({
    required String title,
    String note = '',
    DateTime? dueDate,
    Recurrence recurrence = Recurrence.none,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    if (title.trim().isEmpty) return;

    isSaving.value = true;
    try {
      final ref = _col(uid).doc();
      final todo = TodoModel(
        id: ref.id,
        title: title.trim(),
        note: note.trim(),
        dueDate: dueDate,
        isCompleted: false,
        createdAt: DateTime.now(),
        recurrence: recurrence,
        pendingSync: true,
      );
      // Optimistically insert; the stream echoes it back (with pendingSync
      // cleared) once the server acknowledges.
      todos.insert(0, todo);
      // Schedule the phone notification before the write is issued — the alarm
      // is local, so a task added offline still fires on time.
      await NotificationService.schedule(todo);
      AppSnackbar.saved('Task added');
      _sync.enqueue(
        () => ref.set(todo.toFirestore()),
        label: 'task',
        onError: () => todos.removeWhere((t) => t.id == ref.id),
      );
    } catch (_) {
      AppSnackbar.error('Could not save task.');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> toggleComplete(String id) async {
    final uid = _uid;
    if (uid == null) return;
    final idx = todos.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final todo = todos[idx];

    // Recurring task being completed: advance dueDate to the next occurrence
    // for display purposes. The OS notification is already self-repeating via
    // matchDateTimeComponents — no cancel/reschedule needed.
    if (!todo.isCompleted &&
        todo.recurrence != Recurrence.none &&
        todo.dueDate != null) {
      final nextDate = _nextOccurrence(todo.dueDate!, todo.recurrence);
      final advanced = todo.copyWith(dueDate: nextDate, pendingSync: true);
      todos[idx] = advanced;
      AppSnackbar.saved('Next occurrence scheduled');
      _sync.enqueue(
        () => _col(uid).doc(id).update({'dueDate': Timestamp.fromDate(nextDate)}),
        label: 'task',
        onError: () => _restore(id, todo),
      );
      return;
    }

    final updated = todo.copyWith(
      isCompleted: !todo.isCompleted,
      pendingSync: true,
    );
    todos[idx] = updated;
    // Cancel the alarm when completing; reschedule if un-completing.
    if (updated.isCompleted) {
      await NotificationService.cancel(id);
    } else {
      await NotificationService.schedule(updated);
    }
    _sync.enqueue(
      () => _col(uid).doc(id).update({'isCompleted': updated.isCompleted}),
      label: 'task',
      onError: () {
        _restore(id, todo);
        // Revert the notification state too.
        if (updated.isCompleted) {
          NotificationService.schedule(todo);
        } else {
          NotificationService.cancel(id);
        }
      },
    );
  }

  /// Puts [original] back at whatever index [id] currently sits, used to roll
  /// back an optimistic edit that the server ultimately rejected.
  void _restore(String id, TodoModel original) {
    final idx = todos.indexWhere((t) => t.id == id);
    if (idx != -1) todos[idx] = original;
  }

  Future<void> updateTodo({
    required String id,
    required String title,
    String note = '',
    DateTime? dueDate,
    Recurrence recurrence = Recurrence.none,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    if (title.trim().isEmpty) return;
    final idx = todos.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    isSaving.value = true;
    final original = todos[idx];
    final updated = original.copyWith(
      title: title.trim(),
      note: note.trim(),
      dueDate: dueDate,
      recurrence: dueDate != null ? recurrence : Recurrence.none,
    );
    todos[idx] = updated.copyWith(pendingSync: true);

    if (updated.dueDate != original.dueDate) {
      await NotificationService.cancel(id);
      await NotificationService.schedule(updated);
    }

    AppSnackbar.saved('Task updated');
    isSaving.value = false;
    _sync.enqueue(
      () => _col(uid).doc(id).update({
        'title': updated.title,
        'note': updated.note,
        'dueDate': updated.dueDate != null
            ? Timestamp.fromDate(updated.dueDate!)
            : null,
        'recurrence': updated.recurrence.name,
      }),
      label: 'task',
      onError: () => _restore(id, original),
    );
  }

  Future<void> deleteTodo(String id) async {
    final uid = _uid;
    if (uid == null) return;
    final idx = todos.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final removed = todos[idx];
    todos.removeAt(idx);
    await NotificationService.cancel(id);
    _sync.enqueue(
      () => _col(uid).doc(id).delete(),
      label: 'task',
      isDelete: true,
      onError: () {
        // Put the task back where it was and restore its alarm.
        todos.insert(idx.clamp(0, todos.length), removed);
        NotificationService.schedule(removed);
      },
    );
  }
}
