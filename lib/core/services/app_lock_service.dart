import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric (or device passcode) lock for the whole app.
///
/// The enabled flag lives in secure storage rather than SharedPreferences: it
/// is a security control, and prefs are plain-text readable on a rooted device.
///
/// Authentication deliberately allows the device passcode as a fallback
/// (`biometricOnly: false`). Biometrics-only would lock a user out of their own
/// data after a cut fingertip or a failed face scan, with no recovery path.
class AppLockService extends GetxService {
  static const _keyEnabled = 'app_lock_enabled';

  /// How long the app may sit in the background before it re-locks. Short
  /// enough to protect a handed-over phone, long enough that glancing at a
  /// notification doesn't demand a fingerprint on return.
  static const Duration gracePeriod = Duration(seconds: 30);

  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  /// Whether the user has turned the lock on.
  final RxBool isEnabled = false.obs;

  /// Whether the lock screen is currently covering the app.
  final RxBool isLocked = false.obs;

  /// True while a system biometric prompt is on screen. The prompt itself
  /// backgrounds the app, which would otherwise be read as "user left" and
  /// restart the grace-period clock.
  bool _prompting = false;

  DateTime? _backgroundedAt;

  /// Loads the persisted setting. Register with `Get.putAsync` so the first
  /// frame already knows whether it must draw the lock screen.
  Future<AppLockService> init() async {
    try {
      isEnabled.value = await _storage.read(key: _keyEnabled) == 'true';
    } on PlatformException catch (e) {
      // A corrupt keystore entry must not brick startup — fail open, since the
      // lock is a convenience layer over Firebase Auth, not the only gate.
      if (kDebugMode) debugPrint('AppLockService: read failed — $e');
      isEnabled.value = false;
    }
    isLocked.value = isEnabled.value;
    return this;
  }

  /// Whether this device can do biometrics or has a passcode set.
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// The enrolled biometric kind, used to label the settings toggle.
  /// Returns 'Face ID', 'Fingerprint' or 'Device passcode'.
  Future<String> biometricLabel() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return 'Face ID';
      if (types.contains(BiometricType.fingerprint) ||
          types.contains(BiometricType.strong)) {
        return 'Fingerprint';
      }
    } on LocalAuthException {
      // Fall through to the passcode label.
    } on PlatformException {
      // Fall through to the passcode label.
    }
    return 'Device passcode';
  }

  /// Turns the lock on or off. Enabling requires a successful authentication
  /// first, so a passer-by can't lock the owner out of their own app.
  ///
  /// Returns whether the setting changed.
  Future<bool> setEnabled(bool enabled) async {
    if (enabled) {
      final ok = await authenticate(
        reason: 'Confirm it\'s you to turn on app lock',
      );
      if (!ok) return false;
    }
    isEnabled.value = enabled;
    isLocked.value = false;
    _backgroundedAt = null;
    try {
      await _storage.write(key: _keyEnabled, value: enabled.toString());
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('AppLockService: write failed — $e');
      isEnabled.value = !enabled;
      return false;
    }
    return true;
  }

  /// Why the last [authenticate] call failed, or null if it succeeded or the
  /// user simply cancelled. Callers use this to explain a refusal that the
  /// system UI didn't already explain itself.
  LocalAuthExceptionCode? lastFailure;

  /// Shows the system biometric / passcode prompt.
  Future<bool> authenticate({
    String reason = 'Unlock YellowFinance',
  }) async {
    _prompting = true;
    lastFailure = null;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Was `stickyAuth` before local_auth 3.x: retry on foregrounding
        // instead of failing when the system backgrounds us mid-prompt.
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      // local_auth 3.x reports failures as this rather than PlatformException,
      // and it does not extend it — the two catches are not redundant.
      lastFailure = e.code;
      if (kDebugMode) debugPrint('AppLockService: auth failed — ${e.code}');
      return false;
    } on PlatformException catch (e) {
      lastFailure = LocalAuthExceptionCode.unknownError;
      if (kDebugMode) debugPrint('AppLockService: auth failed — ${e.code}');
      return false;
    } finally {
      _prompting = false;
    }
  }

  /// A user-facing explanation for [lastFailure], or null when the failure
  /// needs no explanation (the user cancelled, or the system already said so).
  String? get lastFailureMessage {
    switch (lastFailure) {
      case null:
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.authInProgress:
        return null;
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'Set a device passcode first — app lock relies on it.';
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return 'No biometrics enrolled on this device.';
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return 'Biometrics aren\'t available on this device.';
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return 'Too many attempts. Unlock your device, then try again.';
      case LocalAuthExceptionCode.timeout:
        return 'That took too long — try again.';
      default:
        return 'Couldn\'t verify it\'s you. Try again.';
    }
  }

  /// Prompts, and drops the lock screen on success.
  Future<bool> unlock() async {
    final ok = await authenticate();
    if (ok) {
      isLocked.value = false;
      _backgroundedAt = null;
    }
    return ok;
  }

  /// Records when the app left the foreground. Called from the lifecycle gate.
  void markBackgrounded() {
    if (!isEnabled.value || _prompting) return;
    _backgroundedAt ??= DateTime.now();
  }

  /// Re-locks if the app was away longer than [gracePeriod].
  void lockIfExpired() {
    if (!isEnabled.value || _prompting) return;
    final since = _backgroundedAt;
    if (since == null) return;
    if (DateTime.now().difference(since) >= gracePeriod) {
      isLocked.value = true;
    }
    _backgroundedAt = null;
  }

  /// Clears lock state without touching the stored preference — used when the
  /// user signs out from the lock screen.
  void release() {
    isLocked.value = false;
    _backgroundedAt = null;
  }
}
