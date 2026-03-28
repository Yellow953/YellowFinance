import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/auth_service.dart';
import '../models/user_model.dart';
import '../providers/firestore_provider.dart';

/// Handles authentication and user profile operations.
class AuthRepository {
  final AuthService _authService;
  final FirestoreProvider _firestore;

  AuthRepository({
    required AuthService authService,
    required FirestoreProvider firestore,
  })  : _authService = authService,
        _firestore = firestore;

  User? get currentUser => _authService.currentUser;
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  /// Registers a new user and creates their Firestore profile.
  Future<UserModel> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _authService.registerWithEmail(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    await _authService.updateDisplayName(displayName);

    final user = UserModel(
      uid: uid,
      displayName: displayName,
      email: email,
      createdAt: DateTime.now(),
    );
    await _firestore.userDoc(uid).set(user.toFirestore());
    return user;
  }

  /// Signs in and returns the user model.
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _authService.signInWithEmail(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    final doc = await _firestore.userDoc(uid).get();
    if (!doc.exists) {
      throw FirebaseException(
        plugin: 'firestore',
        message: 'User profile not found.',
      );
    }
    return UserModel.fromFirestore(doc);
  }

  /// Signs in with Google, creating a Firestore profile if first time.
  Future<UserModel> signInWithGoogle() async {
    final credential = await _authService.signInWithGoogle();
    final firebaseUser = credential.user!;
    final uid = firebaseUser.uid;

    final doc = await _firestore.userDoc(uid).get();
    if (!doc.exists) {
      // First Google sign-in — create profile
      final user = UserModel(
        uid: uid,
        displayName: firebaseUser.displayName ?? '',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL ?? '',
        createdAt: DateTime.now(),
      );
      await _firestore.userDoc(uid).set(user.toFirestore());
      return user;
    }
    return UserModel.fromFirestore(doc);
  }

  /// Sends a password reset email.
  Future<void> sendPasswordReset(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  /// Signs out.
  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// Fetches the current user's profile.
  Future<UserModel?> fetchCurrentUser() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.userDoc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Updates the user's display name in Firestore and Firebase Auth.
  Future<void> updateDisplayName(String uid, String displayName) async {
    await _authService.updateDisplayName(displayName);
    await _firestore.userDoc(uid).update({'displayName': displayName});
  }

  /// Updates the user's preferred currency in Firestore.
  Future<void> updateCurrency(String uid, String currency) async {
    await _firestore.userDoc(uid).update({'currency': currency});
  }

  bool get isEmailVerified => _authService.isEmailVerified;

  Future<void> reloadUser() => _authService.reloadUser();
}
