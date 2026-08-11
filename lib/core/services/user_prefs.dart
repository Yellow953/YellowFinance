import 'package:shared_preferences/shared_preferences.dart';

/// Namespaces SharedPreferences keys to the signed-in account.
///
/// These settings are not financial records, but they are still one account's:
/// a device-global key means a second user on the same phone inherits the first
/// user's Home filters and reminder schedule, and the first user's preferences
/// are overwritten in return. Suffixing the uid keeps each account's settings
/// separate and intact across sign-outs.
///
/// [keyFor] returns null while signed out, which callers treat as "no value" —
/// so a stray read falls back to defaults and a stray write is dropped instead
/// of landing in a shared key.
abstract class UserPrefs {
  static String? _uid;

  /// The account settings are currently being read and written for.
  static String? get uid => _uid;

  /// Points subsequent reads and writes at [uid]. Pass null on sign-out.
  static void bind(String? uid) => _uid = uid;

  /// The account-scoped form of [base], or null when signed out.
  static String? keyFor(String base) => _uid == null ? null : '$base::$_uid';

  /// Keys written before settings were account-scoped.
  static const _legacyKeys = <String>[
    'home_excluded_income_categories',
    'home_excluded_expense_categories',
    'nofap_enabled',
    'nofap_hour',
    'nofap_minute',
    'sport_reminder_enabled',
    'sport_reminder_hour',
    'sport_reminder_minute',
    'hide_balances',
  ];

  /// Adopts any pre-namespacing settings for the bound account, once.
  ///
  /// Without this an upgrade silently resets everyone: Home filters revert and,
  /// worse, the reminder toggles read back false, so notifications people rely
  /// on stop arriving with no visible cause. The device's existing settings
  /// belong to whoever is signed in at upgrade time, so they move to that
  /// account and the shared key is removed.
  static Future<void> migrateLegacyKeys() async {
    if (_uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    for (final legacy in _legacyKeys) {
      final value = prefs.get(legacy);
      if (value == null) continue;
      final scoped = keyFor(legacy)!;
      // Never clobber settings the account already has scoped.
      if (prefs.get(scoped) == null) {
        if (value is bool) {
          await prefs.setBool(scoped, value);
        } else if (value is int) {
          await prefs.setInt(scoped, value);
        } else if (value is double) {
          await prefs.setDouble(scoped, value);
        } else if (value is String) {
          await prefs.setString(scoped, value);
        } else if (value is List) {
          await prefs.setStringList(scoped, value.cast<String>());
        }
      }
      await prefs.remove(legacy);
    }
  }
}
