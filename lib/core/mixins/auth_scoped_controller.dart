import 'package:get/get.dart';

import '../../data/models/user_model.dart';
import '../../modules/auth/controllers/auth_controller.dart';

/// Binds a controller's data to whichever user is currently signed in.
///
/// Every feature controller reads from `users/{uid}/…`, so its state belongs to
/// one account and must not outlive that account's session. Relying on GetX to
/// dispose the controller is not enough: `ever()` returns a [Worker] that is
/// never auto-disposed, and a worker registered against the *permanent*
/// [AuthController] keeps its controller reachable long after the route that
/// created it is gone. Such a survivor still holds the previous user's list and
/// a live listener on their collections — and because Firestore serves cached
/// reads without consulting security rules, that listener keeps returning their
/// documents after sign-out instead of failing.
///
/// This mixin makes the binding explicit and symmetrical: [onUserBound] starts
/// listeners for a uid, [onUserUnbound] tears them down and clears everything
/// derived from that uid, and the worker driving both is disposed with the
/// controller. A uid *change* unbinds before it binds, so switching accounts
/// can never leave the previous user's data on screen.
mixin AuthScopedController on GetxController {
  Worker? _authWorker;
  String? _boundUid;

  /// The uid this controller's state currently belongs to, or null when signed
  /// out. Prefer this over reading [AuthController] directly: a write should go
  /// to the account whose data is loaded, not to whoever happens to be signed
  /// in by the time the write runs.
  String? get boundUid => _boundUid;

  /// Starts listeners and loads data for [uid].
  void onUserBound(String uid);

  /// Cancels every subscription started by [onUserBound] and clears all state
  /// derived from that user. Called on sign-out, on account switch, and on
  /// dispose — so it must be safe to run more than once.
  void onUserUnbound();

  /// Wires the controller to auth state. Call at the end of `onInit`.
  ///
  /// Binds immediately if a user is already signed in; otherwise the first
  /// emission does it. Cold start needs the second path: `main()` routes
  /// straight to Home from Firebase's cached session while the profile is still
  /// being fetched, so controllers are built before `user` is populated.
  ///
  /// [source] defaults to the app's [AuthController] and exists so tests can
  /// drive the lifecycle without a Firebase session.
  void bindToAuth({Rx<UserModel?>? source}) {
    final users = source ?? Get.find<AuthController>().user;
    _authWorker = ever<UserModel?>(users, _handleUserChange);
    _handleUserChange(users.value);
  }

  void _handleUserChange(UserModel? user) {
    final uid = user?.uid;
    if (uid == _boundUid) return;
    if (_boundUid != null) {
      // Cleared *before* the callback, not after: clearing an observable during
      // teardown can wake a `ever(...)` worker that resubscribes, and a null
      // [boundUid] makes that resubscribe a no-op instead of re-attaching to
      // the account being torn down.
      _boundUid = null;
      onUserUnbound();
    }
    _boundUid = uid;
    if (uid != null) onUserBound(uid);
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    _authWorker = null;
    if (_boundUid != null) {
      _boundUid = null;
      onUserUnbound();
    }
    super.onClose();
  }
}
