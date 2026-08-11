import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_service.dart';
import 'user_prefs.dart';

/// Daily reminder to log your sport entry so you don't break your streak.
///
/// Unlike a plain daily nudge, this only nags when there is something to
/// protect: reminders are scheduled **only while a streak is active** and
/// today's reminder is skipped once an entry has been logged. The current
/// streak / logged-today state is fed in via [sync], which [HomeController]
/// calls on every sports snapshot (and on app start).
abstract class SportReminderService {
  static const _prefEnabled = 'sport_reminder_enabled';
  static const _prefHour = 'sport_reminder_hour';
  static const _prefMinute = 'sport_reminder_minute';

  static const _notifIdBase = 777000; // reserves 777000–777013
  static const _scheduleDays = 14; // one-shot notifs scheduled this far ahead
  static const _channelId = 'sport_reminders';
  static const _channelName = 'Sport Reminders';

  static final _plugin = FlutterLocalNotificationsPlugin();

  static final _messages = const [
    "Don't break the chain. Log today's session and keep the streak alive. 🔥",
    "Your streak is watching. Get a set in and log it before the day's gone.",
    "A quick workout beats a broken streak. Move, then log it. 💪",
    "Still time to keep it going. Even 10 minutes counts — log your entry.",
    "Streaks are built on the days you didn't feel like it. Today's one of them.",
    "You haven't logged today. Future you would like a word. Go move. 🏃",
    "Consistency compounds. Add today's entry and protect the streak.",
    "One missed day resets everything. Don't let it be today. Log it. ⏳",
    "The hard part is starting. The easy part is logging it after. Go.",
    "Keep the momentum — a small session today keeps the streak intact.",
  ];

  // ── Persistence ─────────────────────────────────────────────────────────

  // Settings belong to the signed-in account, not the device — see [UserPrefs].
  // A null key means signed out: reads fall back to defaults and writes drop.

  static Future<bool> isEnabled() async {
    final key = UserPrefs.keyFor(_prefEnabled);
    if (key == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  static Future<int> savedHour() async {
    final key = UserPrefs.keyFor(_prefHour);
    if (key == null) return 23;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? 23; // default 11 PM
  }

  static Future<int> savedMinute() async {
    final key = UserPrefs.keyFor(_prefMinute);
    if (key == null) return 0;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? 0;
  }

  static Future<void> setEnabled(bool value) async {
    final key = UserPrefs.keyFor(_prefEnabled);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<void> setTime({required int hour, required int minute}) async {
    final hourKey = UserPrefs.keyFor(_prefHour);
    final minuteKey = UserPrefs.keyFor(_prefMinute);
    if (hourKey == null || minuteKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(hourKey, hour);
    await prefs.setInt(minuteKey, minute);
  }

  // ── Scheduling ───────────────────────────────────────────────────────────

  /// Reconciles scheduled reminders with the current state. Safe to call
  /// often — it cancels and re-schedules from scratch each time.
  ///
  /// Nothing is scheduled unless the feature is enabled AND [hasStreak] is
  /// true. Today's reminder is skipped when [loggedToday] is true or its time
  /// has already passed.
  static Future<void> sync({
    required bool hasStreak,
    required bool loggedToday,
  }) async {
    await _cancelAll();

    if (!await isEnabled()) return;
    if (!hasStreak) return; // no streak to protect — stay quiet

    final hour = await savedHour();
    final minute = await savedMinute();

    final shuffled = List.of(_messages)..shuffle(Random());
    final now = DateTime.now(); // local time — avoids UTC date-component bug
    int scheduled = 0;

    for (int day = 0; scheduled < _scheduleDays; day++) {
      // Guard against an unbounded loop if every remaining slot is skipped.
      if (day > _scheduleDays * 2) break;

      final localDt = DateTime(now.year, now.month, now.day + day, hour, minute);
      final tzDt = tz.TZDateTime.from(localDt, tz.local);

      // Skip a slot in the past (feature enabled after today's time) and skip
      // today entirely if an entry was already logged.
      if (tzDt.isBefore(tz.TZDateTime.now(tz.local))) continue;
      if (day == 0 && loggedToday) continue;

      await _plugin.zonedSchedule(
        id: _notifIdBase + scheduled,
        title: '🏃 Keep your streak',
        body: shuffled[scheduled % shuffled.length],
        scheduledDate: tzDt,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Daily reminder to log your sport entry',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // Tapping opens the Sports page with the add sheet (see
        // NotificationService._onTap).
        payload: NotificationService.sportsPayload,
      );

      scheduled++;
    }
  }

  /// Cancels every scheduled reminder. Called on sign-out so one account's
  /// reminders don't keep firing for the next person to use the device.
  static Future<void> cancelAll() => _cancelAll();

  static Future<void> _cancelAll() async {
    for (int i = 0; i < _scheduleDays; i++) {
      await _plugin.cancel(id: _notifIdBase + i);
    }
  }
}
