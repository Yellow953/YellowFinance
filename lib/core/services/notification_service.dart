import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/todo_model.dart';
import '../../routes/app_routes.dart';

/// Maps a [Recurrence] value to the [DateTimeComponents] that makes
/// [zonedSchedule] auto-repeat at that cadence. Returns null for one-shot tasks.
DateTimeComponents? _repeatFor(Recurrence r) {
  switch (r) {
    case Recurrence.daily:
      return DateTimeComponents.time; // same time every day
    case Recurrence.weekly:
      return DateTimeComponents.dayOfWeekAndTime; // same day+time every week
    case Recurrence.monthly:
      return DateTimeComponents.dayOfMonthAndTime; // same day+time every month
    case Recurrence.none:
      return null;
  }
}

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

  /// Payload marking a notification that should open the Sports page's add
  /// sheet when tapped (used by [SportReminderService]).
  static const sportsPayload = 'sports';

  /// Set when a notification launches a terminated app.
  /// HomeController consumes this on first load.
  static String? pendingRoute;

  /// Route arguments to pass alongside [pendingRoute] (e.g. 'add' to open a
  /// page's add sheet). Consumed together with [pendingRoute].
  static Object? pendingArguments;

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_ready) return;

    // Load timezone database (device local timezone is picked automatically).
    tz.initializeTimeZones();

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onTap,
    );

    // Handle notification tap when the app was fully terminated.
    // Store as pending — GetX isn't ready yet, HomeController will navigate.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload == sportsPayload) {
        pendingRoute = AppRoutes.SPORTS;
        pendingArguments = 'add';
      } else {
        pendingRoute = AppRoutes.TODOS;
      }
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

  static void _onTap(NotificationResponse response) {
    // Use offAllNamed so the back-stack doesn't accumulate.
    if (response.payload == sportsPayload) {
      // Sports isn't a tab, so it opens on top of Home for its back button.
      Future.delayed(Duration.zero, () {
        Get.offAllNamed(AppRoutes.HOME);
        Get.toNamed(AppRoutes.SPORTS, arguments: 'add');
      });
    } else {
      Future.delayed(Duration.zero, () => Get.offAllNamed(AppRoutes.TODOS));
    }
  }

  // ── ID mapping ────────────────────────────────────────────────────────────

  // Maps a Firestore document ID (string) to a stable int notification ID.
  static int _idFor(String todoId) => todoId.hashCode.abs() % 2000000000;

  // Separate ID for the 10-minute-early reminder (different hash seed).
  static int _earlyIdFor(String todoId) =>
      '${todoId}_early'.hashCode.abs() % 2000000000;

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

    final now = DateTime.now();

    final repeat = _repeatFor(todo.recurrence);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Reminders for your scheduled tasks',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // On-time notification.
    // For recurring tasks, matchDateTimeComponents tells the OS to auto-repeat
    // at the chosen cadence — no app involvement needed for future occurrences.
    if (due.isAfter(now) || repeat != null) {
      await _plugin.zonedSchedule(
        id: _idFor(todo.id),
        title: 'Task due now',
        body: todo.title,
        scheduledDate: tz.TZDateTime.from(due, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: repeat,
        payload: todo.id,
      );
    }

    // 10-minute early reminder (same repeat cadence as the main notification).
    final early = due.subtract(const Duration(minutes: 10));
    if (early.isAfter(now) || repeat != null) {
      await _plugin.zonedSchedule(
        id: _earlyIdFor(todo.id),
        title: 'Task due in 10 minutes',
        body: todo.title,
        scheduledDate: tz.TZDateTime.from(early, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: repeat,
        payload: todo.id,
      );
    }
  }

  /// Cancels both the on-time and early notifications for [todoId].
  static Future<void> cancel(String todoId) async {
    await Future.wait([
      _plugin.cancel(id: _idFor(todoId)),
      _plugin.cancel(id: _earlyIdFor(todoId)),
    ]);
  }

  /// Cancels every scheduled task notification.
  ///
  /// Used on sign-out: reminders are scheduled from one account's tasks and
  /// must not keep firing for whoever signs in next on this device.
  static Future<void> cancelAll() => _plugin.cancelAll();

  /// Called once on app start to re-register any notifications that may have
  /// been lost (e.g. if the user cleared app data). The plugin's boot receiver
  /// normally handles rescheduling after a reboot, so this is a safety net.
  static Future<void> rescheduleAll(List<TodoModel> todos) async {
    for (final todo in todos) {
      await schedule(todo);
    }
  }
}
