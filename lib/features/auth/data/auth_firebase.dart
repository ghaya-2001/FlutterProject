import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_user.dart';
import '../domain/auth_failure.dart';

/// Email/password accounts with Firebase Authentication.
///
/// Every method throws [AuthFailure] instead of Firebase exceptions, so the
/// rest of the app never depends on `firebase_auth` directly.
class AuthFirebase {
  AuthFirebase({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  /// Sent on sign-in, sign-out and profile changes (name, verification).
  Stream<AppUser?> watchUser() => _auth.userChanges().map(_toAppUser);

  /// Creates the account, sets its name and sends the verification email.
  Future<AppUser> signUp({
    required String displayName,
    required String email,
    required String password,
  }) {
    return _guard(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(displayName);
      // Verification doesn't block the app, so a failed email is not fatal.
      await user.sendEmailVerification().catchError((_) {});
      await user.reload();
      return _toAppUser(_auth.currentUser ?? user)!;
    });
  }

  Future<AppUser> signIn({required String email, required String password}) {
    return _guard(() async {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _toAppUser(credential.user)!;
    });
  }

  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email));

  Future<void> sendEmailVerification() =>
      _guard(() => _signedInUser().sendEmailVerification());

  /// Reloads the account, e.g. to see whether the email was just verified.
  Future<AppUser> reload() {
    return _guard(() async {
      await _signedInUser().reload();
      return _toAppUser(_auth.currentUser)!;
    });
  }

  Future<void> updateDisplayName(String displayName) =>
      _guard(() => _signedInUser().updateDisplayName(displayName));

  /// Confirms the current password. Firebase requires a recent sign-in
  /// before changing the password or deleting the account.
  Future<void> reauthenticate(String password) {
    return _guard(() async {
      final user = _signedInUser();
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    });
  }

  Future<void> updatePassword(String newPassword) =>
      _guard(() => _signedInUser().updatePassword(newPassword));

  Future<void> deleteUser() => _guard(() => _signedInUser().delete());

  Future<void> signOut() => _guard(_auth.signOut);

  User _signedInUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthFailure('not-signed-in');
    }
    return user;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(error.code);
    }
  }
}

AppUser? _toAppUser(User? user) {
  if (user == null) {
    return null;
  }
  return AppUser(
    uid: user.uid,
    email: user.email ?? '',
    displayName: user.displayName ?? '',
    emailVerified: user.emailVerified,
  );
}
