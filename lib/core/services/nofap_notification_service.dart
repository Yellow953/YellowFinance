import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'user_prefs.dart';

/// Daily No-Fap motivational reminders — scheduled once, repeat every 24 h.
abstract class NofapNotificationService {
  static const _prefEnabled = 'nofap_enabled';
  static const _prefHour = 'nofap_hour';
  static const _prefMinute = 'nofap_minute';

  static const _notifIdBase = 888999; // unique base; reserves 888999–889018
  static const _scheduleDays = 20; // one-shot notifs scheduled this far ahead
  static const _channelId = 'nofap_reminders';
  static const _channelName = 'No-Fap Reminders';

  static final _plugin = FlutterLocalNotificationsPlugin();

  static final _messages = const [
    "Keep your hands where I can see them. 👀 Another clean day.",
    "The urge will pass in 10 minutes. It always does. Drink water and wait it out. 💧",
    "Your dopamine receptors are healing right now. Don't interrupt the reboot.",
    "Breaking news: Local man keeps it in his pants. Self-respect at an all-time high.",
    "Step away from the browser. I know what you were about to do.",
    "Your streak is an asset. Don't liquidate it for 15 minutes of nothing.",
    "The urge is a liar — promises everything, delivers shame. You already know this.",
    "Put the phone down. Take a cold shower. Thank me later. 🚿",
    "Scientifically speaking, your testosterone is climbing. Don't flush it.",
    "Your ancestors survived famine and war. You can survive tonight. Stay strong.",
    "Every time you resist, the neural pathway gets weaker. You're literally rewiring your brain.",
    "You vs. monkey brain. Monkey brain is 0 for today. Keep it that way. 🧠",
    "Thought experiment: what if you used that energy to do something you'll remember tomorrow?",
    "Sir, close the tab. This is not a drill.",
    "The algorithm knows. Your future self is watching. Don't disappoint either of them.",
    "Real confidence isn't built in 15 minutes of weakness. It's built in moments like this.",
    "Channel that energy into something that compounds — like investing. You have an app for that. 📈",
    "Day loading... willpower: 100%. Keep it that way.",
    "Your streak is your most underrated asset. Protect it like your portfolio.",
    "Another night, another W. Go to sleep, king. 👑",
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
    if (key == null) return 30;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? 30; // default :30
  }

  // ── Enable / disable ─────────────────────────────────────────────────────

  static Future<void> enable({required int hour, required int minute}) async {
    final enabledKey = UserPrefs.keyFor(_prefEnabled);
    final hourKey = UserPrefs.keyFor(_prefHour);
    final minuteKey = UserPrefs.keyFor(_prefMinute);
    if (enabledKey == null || hourKey == null || minuteKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, true);
    await prefs.setInt(hourKey, hour);
    await prefs.setInt(minuteKey, minute);
    await _schedule(hour: hour, minute: minute);
  }

  static Future<void> disable() async {
    final key = UserPrefs.keyFor(_prefEnabled);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, false);
    await _cancelAll();
  }

  /// Cancels every scheduled reminder without touching the stored setting.
  /// Used on sign-out so one account's reminders don't fire for the next.
  static Future<void> cancelAll() => _cancelAll();

  static Future<void> rescheduleIfEnabled() async {
    if (!await isEnabled()) return;
    final h = await savedHour();
    final m = await savedMinute();
    await _schedule(hour: h, minute: m);
  }

  // ── Internal scheduler ───────────────────────────────────────────────────

  static Future<void> _cancelAll() async {
    for (int i = 0; i < _scheduleDays; i++) {
      await _plugin.cancel(id: _notifIdBase + i);
    }
  }

  /// Schedules [_scheduleDays] one-shot notifications, one per day, each with
  /// a different randomly-shuffled message. Using one-shot instead of
  /// matchDateTimeComponents means the body changes every day.
  ///
  /// Uses [DateTime.now()] (local clock) to build fire times, then converts
  /// via [tz.TZDateTime.from] so the UTC offset is handled correctly — this
  /// matches how task notifications are scheduled and fixes the 2-hour drift
  /// that occurred when building TZDateTime directly from UTC date components.
  static Future<void> _schedule({
    required int hour,
    required int minute,
  }) async {
    await _cancelAll();

    final shuffled = List.of(_messages)..shuffle(Random());
    final now = DateTime.now(); // local time — avoids UTC date-component bug
    int scheduled = 0;

    for (int day = 0; scheduled < _scheduleDays; day++) {
      final localDt = DateTime(now.year, now.month, now.day + day, hour, minute);
      final tzDt = tz.TZDateTime.from(localDt, tz.local);

      // Today's slot may already be in the past if the user just enabled the
      // feature after the chosen time — skip it, start from tomorrow.
      if (tzDt.isBefore(tz.TZDateTime.now(tz.local))) continue;

      await _plugin.zonedSchedule(
        id: _notifIdBase + scheduled,
        title: '🔒 Stay Strong',
        body: shuffled[scheduled % shuffled.length],
        scheduledDate: tzDt,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Daily No-Fap motivational reminders',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // No matchDateTimeComponents — each notification is unique and one-shot.
      );

      scheduled++;
    }
  }
}
