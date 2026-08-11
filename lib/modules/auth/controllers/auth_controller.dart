import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/home_category_filter_service.dart';
import '../../../core/services/nofap_notification_service.dart';
import '../../../core/services/sport_reminder_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/services/user_prefs.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routes/app_routes.dart';

/// Manages authentication state and user session.
class AuthController extends GetxController {
  final AuthRepository _authRepo;

  final Rx<UserModel?> user = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool hideBalances = false.obs;

  static const _hideKey = 'hide_balances';
  SharedPreferences? _prefs;

  AuthController({required AuthRepository authRepo}) : _authRepo = authRepo;

  @override
  void onReady() {
    super.onReady();
    _listenToAuthChanges();
    // Device-local settings are per-account too. Driving them from `user` keeps
    // every path — sign-in, sign-out, account switch — going through one place.
    ever<UserModel?>(user, (u) => _applyUserScopedPrefs(u?.uid));
    _loadHidePreference();
  }

  /// Re-points device-local settings at [uid], or tears them down when null.
  Future<void> _applyUserScopedPrefs(String? uid) async {
    // Synchronous and first: everything below reads through this binding.
    UserPrefs.bind(uid);

    if (uid == null) {
      // The stored values survive — only what is live on the device stops.
      await NofapNotificationService.cancelAll();
      await SportReminderService.cancelAll();
      Get.find<HomeCategoryFilterService>().clear();
      hideBalances.value = false;
      return;
    }

    await UserPrefs.migrateLegacyKeys();
    await Get.find<HomeCategoryFilterService>().reload();
    await _loadHidePreference();
    // Reminders were cancelled on the previous sign-out; put this account's
    // back if it has them switched on.
    await NofapNotificationService.rescheduleIfEnabled();
  }

  Future<void> _loadHidePreference() async {
    final key = UserPrefs.keyFor(_hideKey);
    if (key == null) {
      hideBalances.value = false;
      return;
    }
    _prefs ??= await SharedPreferences.getInstance();
    hideBalances.value = _prefs!.getBool(key) ?? false;
  }

  Future<void> toggleHideBalances() async {
    final key = UserPrefs.keyFor(_hideKey);
    if (key == null) return;
    hideBalances.value = !hideBalances.value;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(key, hideBalances.value);
  }

  void _listenToAuthChanges() {
    _authRepo.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser == null) {
        user.value = null;
        if (Get.currentRoute != AppRoutes.LOGIN) {
          Get.offAllNamed(AppRoutes.LOGIN);
        }
      } else {
        // Google users are always verified — only gate email/password accounts.
        final isVerified = firebaseUser.emailVerified ||
            firebaseUser.providerData
                .any((p) => p.providerId == 'google.com');

        if (!isVerified) {
          if (Get.currentRoute != AppRoutes.VERIFY_EMAIL) {
            Get.offAllNamed(AppRoutes.VERIFY_EMAIL);
          }
          return;
        }

        final profile = await _authRepo.fetchCurrentUser();
        user.value = profile;
        if (Get.currentRoute == AppRoutes.LOGIN ||
            Get.currentRoute == AppRoutes.REGISTER ||
            Get.currentRoute == AppRoutes.VERIFY_EMAIL) {
          Get.offAllNamed(AppRoutes.HOME);
        }
      }
    });
  }

  /// Registers a new account.
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await _authRepo.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      _showSnackbar(
        'Account created! Check your email to verify your address.',
        isError: false,
      );
      Get.offAllNamed(AppRoutes.LOGIN);
    } catch (e) {
      errorMessage.value = _friendlyError(e);
      _showSnackbar(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Signs in with email and password.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final userModel = await _authRepo.signIn(
        email: email,
        password: password,
      );
      user.value = userModel;
      Get.offAllNamed(AppRoutes.HOME);
    } catch (e) {
      errorMessage.value = _friendlyError(e);
      _showSnackbar(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  /// Signs in with Google.
  Future<void> signInWithGoogle() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final userModel = await _authRepo.signInWithGoogle();
      user.value = userModel;
      Get.offAllNamed(AppRoutes.HOME);
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('sign-in-cancelled')) {
        errorMessage.value = _friendlyError(e);
        _showSnackbar(errorMessage.value);
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Sends a password reset email.
  Future<void> sendPasswordReset(String email) async {
    isLoading.value = true;
    try {
      await _authRepo.sendPasswordReset(email);
      _showSnackbar(
        'Password reset email sent. Check your inbox.',
        isError: false,
      );
    } catch (e) {
      _showSnackbar(_friendlyError(e));
    } finally {
      isLoading.value = false;
    }
  }

  /// Updates display name and/or currency on the user's profile.
  Future<void> updateProfile({
    String? displayName,
    String? currency,
  }) async {
    final uid = user.value?.uid;
    if (uid == null) return;
    isLoading.value = true;
    try {
      if (displayName != null && displayName.isNotEmpty) {
        await _authRepo.updateDisplayName(uid, displayName);
      }
      if (currency != null) {
        await _authRepo.updateCurrency(uid, currency);
      }
      final updated = await _authRepo.fetchCurrentUser();
      user.value = updated;
      _showSnackbar('Profile updated.', isError: false);
    } catch (e) {
      _showSnackbar(_friendlyError(e));
    } finally {
      isLoading.value = false;
    }
  }

  /// Resends the verification email.
  Future<void> resendVerificationEmail() async {
    isLoading.value = true;
    try {
      await Get.find<AuthService>().currentUser?.sendEmailVerification();
      _showSnackbar('Verification email sent. Check your inbox.',
          isError: false);
    } catch (e) {
      _showSnackbar(_friendlyError(e));
    } finally {
      isLoading.value = false;
    }
  }

  /// Reloads the Firebase user to check if email has been verified.
  Future<void> checkEmailVerified() async {
    isLoading.value = true;
    try {
      await Get.find<AuthService>().reloadUser();
      final firebaseUser = Get.find<AuthService>().currentUser;
      if (firebaseUser?.emailVerified == true) {
        final profile = await _authRepo.fetchCurrentUser();
        user.value = profile;
        Get.offAllNamed(AppRoutes.HOME);
      } else {
        _showSnackbar('Email not verified yet. Please check your inbox.');
      }
    } catch (e) {
      _showSnackbar(_friendlyError(e));
    } finally {
      isLoading.value = false;
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    // Null the user *before* Firebase tears the session down, and synchronously.
    // Every auth-scoped controller is watching this value, so this is what
    // cancels their listeners and clears their lists — waiting for
    // `authStateChanges` to do it leaves a window where the previous account's
    // data is still on screen and still being streamed.
    user.value = null;

    await _authRepo.signOut();

    // The listener normally handles this; doing it here keeps teardown ordered
    // (routes gone before the instances they used are dropped). Re-entry is
    // guarded by the currentRoute check in the listener.
    if (Get.currentRoute != AppRoutes.LOGIN) {
      await Get.offAllNamed(AppRoutes.LOGIN);
    }

    // Drop the controller instances themselves. `force: false` leaves the
    // permanent services — and this AuthController — registered, so the login
    // screen still works. Without this, a controller whose route disposal was
    // missed survives as a live object holding the previous account's data.
    await Get.deleteAll();

    await _flagCacheClear();
  }

  /// Asks the next launch to wipe Firestore's on-disk cache.
  ///
  /// Firestore only allows `clearPersistence()` before the client starts, so it
  /// cannot run here — it is deferred to `main()`. That is safe now that
  /// nothing listens on the signed-out account's paths: the stale cache is data
  /// at rest, not something the app can read back into a session. It matters
  /// because cached reads bypass security rules entirely, so anything left on
  /// disk would be served without an auth check if it were ever queried.
  ///
  /// Skipped when writes are still queued — clearing persistence discards
  /// Firestore's pending-write queue, which would silently drop changes made
  /// offline.
  Future<void> _flagCacheClear() async {
    if (Get.find<SyncService>().pendingTotal > 0) return;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(AppConstants.prefPendingCacheClear, true);
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('user-not-found') || msg.contains('wrong-password') ||
        msg.contains('invalid-credential')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('email-already-in-use')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('network')) {
      return 'Network error. Check your connection.';
    }
    if (kDebugMode) return e.toString();
    return 'Something went wrong. Please try again.';
  }

  void _showSnackbar(String message, {bool isError = true}) {
    AppSnackbar.show(
      isError ? 'Error' : 'Done',
      message,
      isError: isError,
    );
  }
}
