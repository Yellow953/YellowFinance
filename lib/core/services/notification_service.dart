import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/todo_model.dart';
import '../../routes/app_routes.dart';

/// Manages on-device scheduled notifications for due tasks.
///
/// Uses exact alarms so the notification fires at the precise due time,
/// even when the app is in the background or the process has been killed.
/// No Firebase / FCM required — everything is local.
abstract class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channelId = 'task_reminders';
  static const _channelName = 'Task Reminders';

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_ready) return;

    // Load timezone database (device local timezone is picked automatically).
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onTap,
    );

    // Handle notification tap when the app was fully terminated.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _navigateToTodos();
    }

    // Request permissions (Android 13+ needs POST_NOTIFICATIONS; 12+ needs
    // exact alarm permission — the user will see a system dialog once).
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    _ready = true;
  }

  // ── Notification tap ──────────────────────────────────────────────────────

  static void _onTap(NotificationResponse response) => _navigateToTodos();

  static void _navigateToTodos() {
    // Use offAllNamed so the back-stack doesn't accumulate.
    Future.delayed(Duration.zero, () => Get.offAllNamed(AppRoutes.TODOS));
  }

  // ── ID mapping ────────────────────────────────────────────────────────────

  // Maps a Firestore document ID (string) to a stable int notification ID.
  static int _idFor(String todoId) => todoId.hashCode.abs() % 2000000000;

  // ── Schedule ──────────────────────────────────────────────────────────────

  /// Schedules a notification for [todo] at its due date/time.
  ///
  /// Skips silently if:
  ///  - no due date is set
  ///  - no specific time was set (hour and minute both 0 — date-only tasks)
  ///  - the due time is already in the past
  ///  - the task is already completed
  static Future<void> schedule(TodoModel todo) async {
    final due = todo.dueDate;
    if (due == null) return;
    if (todo.isCompleted) return;
    if (due.hour == 0 && due.minute == 0) return; // date-only, no alarm time
    if (due.isBefore(DateTime.now())) return;

    final scheduled = tz.TZDateTime.from(due, tz.local);

    await _plugin.zonedSchedule(
      id: _idFor(todo.id),
      title: 'Task due now',
      body: todo.title,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Reminders for your scheduled tasks',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: todo.id,
    );
  }

  /// Cancels the pending notification for [todoId] (on complete or delete).
  static Future<void> cancel(String todoId) async {
    await _plugin.cancel(id: _idFor(todoId));
  }

  /// Called once on app start to re-register any notifications that may have
  /// been lost (e.g. if the user cleared app data). The plugin's boot receiver
  /// normally handles rescheduling after a reboot, so this is a safety net.
  static Future<void> rescheduleAll(List<TodoModel> todos) async {
    for (final todo in todos) {
      await schedule(todo);
    }
  }
}
