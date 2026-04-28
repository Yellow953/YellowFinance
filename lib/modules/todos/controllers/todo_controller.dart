import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../core/services/notification_service.dart';
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

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  bool _rescheduled = false;

  @override
  void onInit() {
    super.onInit();
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
    super.onClose();
  }

  String? get _uid => Get.find<AuthController>().user.value?.uid;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('todos');

  // ── Stream subscription ───────────────────────────────────────────────────
  // snapshots() serves from Firestore's local cache immediately, then updates
  // from the server — giving a fast first paint and full offline support.

  void _subscribe() {
    final uid = _uid;
    if (uid == null) return;
    isLoading.value = true;
    _sub = _col(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
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

  // ── CRUD ──────────────────────────────────────────────────────────────────
  // Writes are optimistic: the local list updates instantly. Firestore queues
  // the write offline and syncs when connectivity is restored.

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
      );
      // Optimistically insert; the stream will confirm once it echoes back.
      todos.insert(0, todo);
      await ref.set(todo.toFirestore());
      // Schedule phone notification at the due time (if time was set).
      await NotificationService.schedule(todo);
      AppSnackbar.success('Task added');
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
      final advanced = todo.copyWith(dueDate: nextDate);
      todos[idx] = advanced;
      try {
        await _col(uid)
            .doc(id)
            .update({'dueDate': Timestamp.fromDate(nextDate)});
        AppSnackbar.success('Next occurrence scheduled');
      } catch (_) {
        todos[idx] = todo;
        AppSnackbar.error('Could not update task.');
      }
      return;
    }

    final updated = todo.copyWith(isCompleted: !todo.isCompleted);
    todos[idx] = updated;
    // Cancel the alarm when completing; reschedule if un-completing.
    if (updated.isCompleted) {
      await NotificationService.cancel(id);
    } else {
      await NotificationService.schedule(updated);
    }
    try {
      await _col(uid).doc(id).update({'isCompleted': updated.isCompleted});
    } catch (_) {
      todos[idx] = todos[idx].copyWith(isCompleted: !updated.isCompleted);
      // Revert the notification state too.
      if (updated.isCompleted) {
        await NotificationService.schedule(todos[idx]);
      } else {
        await NotificationService.cancel(id);
      }
      AppSnackbar.error('Could not update task.');
    }
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
    todos[idx] = updated;

    if (updated.dueDate != original.dueDate) {
      await NotificationService.cancel(id);
      await NotificationService.schedule(updated);
    }

    try {
      await _col(uid).doc(id).update({
        'title': updated.title,
        'note': updated.note,
        'dueDate': updated.dueDate != null
            ? Timestamp.fromDate(updated.dueDate!)
            : null,
        'recurrence': updated.recurrence.name,
      });
      AppSnackbar.success('Task updated');
    } catch (_) {
      todos[idx] = original;
      AppSnackbar.error('Could not update task.');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteTodo(String id) async {
    final uid = _uid;
    if (uid == null) return;
    todos.removeWhere((t) => t.id == id);
    await NotificationService.cancel(id);
    try {
      await _col(uid).doc(id).delete();
    } catch (_) {
      AppSnackbar.error('Could not delete task.');
    }
  }
}
