import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps [FlutterSecureStorage] for sensitive local data.
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keyLastActiveAt = 'last_active_at';

  /// Stores when the user was last active (for inactivity sign-out).
  Future<void> setLastActiveAt(DateTime time) async {
    await _storage.write(
      key: _keyLastActiveAt,
      value: time.millisecondsSinceEpoch.toString(),
    );
  }

  /// Returns the last active timestamp, or null if not set.
  Future<DateTime?> getLastActiveAt() async {
    final value = await _storage.read(key: _keyLastActiveAt);
    if (value == null) return null;
    final ms = int.tryParse(value);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Clears all stored secure values.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}