import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/services/auth_service.dart';
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
    _loadHidePreference();
  }

  Future<void> _loadHidePreference() async {
    _prefs ??= await SharedPreferences.getInstance();
    hideBalances.value = _prefs!.getBool(_hideKey) ?? false;
  }

  Future<void> toggleHideBalances() async {
    hideBalances.value = !hideBalances.value;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_hideKey, hideBalances.value);
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
    await _authRepo.signOut();
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
