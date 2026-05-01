import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Daily No-Fap motivational reminders — scheduled once, repeat every 24 h.
abstract class NofapNotificationService {
  static const _prefEnabled = 'nofap_enabled';
  static const _prefHour = 'nofap_hour';
  static const _prefMinute = 'nofap_minute';

  static const _notifId = 888999; // unique, won't clash with task IDs
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

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabled) ?? false;
  }

  static Future<int> savedHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefHour) ?? 23; // default 11 PM
  }

  static Future<int> savedMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefMinute) ?? 30; // default :30
  }

  // ── Enable / disable ─────────────────────────────────────────────────────

  static Future<void> enable({required int hour, required int minute}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, true);
    await prefs.setInt(_prefHour, hour);
    await prefs.setInt(_prefMinute, minute);
    await _schedule(hour: hour, minute: minute);
  }

  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, false);
    await _plugin.cancel(id: _notifId);
  }

  static Future<void> rescheduleIfEnabled() async {
    if (!await isEnabled()) return;
    final h = await savedHour();
    final m = await savedMinute();
    await _schedule(hour: h, minute: m);
  }

  // ── Internal scheduler ───────────────────────────────────────────────────

  static Future<void> _schedule({
    required int hour,
    required int minute,
  }) async {
    await _plugin.cancel(id: _notifId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final body = _messages[Random().nextInt(_messages.length)];

    await _plugin.zonedSchedule(
      id: _notifId,
      title: '🔒 Stay Strong',
      body: body,
      scheduledDate: scheduled,
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
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
    );
  }
}
