import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/firebase/firebase_setup.dart';
import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import 'auth_firebase.dart';

/// Store for the signed-in account (Membre 1).
///
/// Screens read [currentUser] and call the methods below; every change calls
/// [notifyListeners]. Methods throw [AuthFailure] with a message ready to show.
///
/// When [remote] is null (tests, or Firebase not configured), accounts are
/// kept in memory so the sign-up / sign-in flow still works.
class AuthRepository extends ChangeNotifier {
  AuthRepository({this.remote}) {
    if (remote != null) {
      _user = remote!.currentUser;
      isLoading = _user == null;
      _subscription = remote!.watchUser().listen(_onRemoteUser);
    }
  }

  static final AuthRepository instance = AuthRepository(
    remote: FirebaseSetup.isReady ? AuthFirebase() : null,
  );

  /// Firebase Authentication; null in tests or when Firebase is not configured.
  final AuthFirebase? remote;

  /// True until Firebase says whether someone is signed in (used by Splash).
  bool isLoading = false;

  AppUser? _user;
  StreamSubscription<AppUser?>? _subscription;

  /// In-memory accounts (only used when [remote] is null), by email.
  final Map<String, _LocalAccount> _localAccounts = {};
  int _idCounter = 0;

  AppUser? get currentUser => _user;

  bool get isSignedIn => _user != null;

  Future<AppUser> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final name = displayName.trim();
    final address = email.trim();
    final user = remote != null
        ? await remote!.signUp(
            displayName: name,
            email: address,
            password: password,
          )
        : _localSignUp(name, address, password);
    _setUser(user);
    return user;
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final address = email.trim();
    final user = remote != null
        ? await remote!.signIn(email: address, password: password)
        : _localSignIn(address, password);
    _setUser(user);
    return user;
  }

  /// Sends a reset link. Succeeds even when no account uses [email], so the
  /// app doesn't reveal which emails are registered.
  Future<void> sendPasswordReset(String email) async {
    await remote?.sendPasswordReset(email.trim());
  }

  Future<void> sendEmailVerification() async {
    _requireUser();
    await remote?.sendEmailVerification();
  }

  /// Refreshes [currentUser], e.g. after the user clicked the verification
  /// link in their email.
  Future<void> reloadUser() async {
    _requireUser();
    if (remote != null) {
      _setUser(await remote!.reload());
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = _requireUser();
    final name = displayName.trim();
    if (remote != null) {
      await remote!.updateDisplayName(name);
    } else {
      _localAccounts[_key(user.email)]!.user = user.copyWith(displayName: name);
    }
    _setUser(user.copyWith(displayName: name));
  }

  /// Checks [password] again before a sensitive change (change password,
  /// delete account).
  Future<void> reauthenticate(String password) async {
    final user = _requireUser();
    if (remote != null) {
      await remote!.reauthenticate(password);
    } else if (_localAccounts[_key(user.email)]!.password != password) {
      throw AuthFailure('wrong-password');
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await reauthenticate(currentPassword);
    if (remote != null) {
      await remote!.updatePassword(newPassword);
    } else {
      _localAccounts[_key(_user!.email)]!.password = newPassword;
    }
  }

  /// Deletes the account itself. Call [reauthenticate] first, and delete the
  /// user's Firestore data before this (the rules need the user signed in).
  Future<void> deleteAccount() async {
    final user = _requireUser();
    if (remote != null) {
      await remote!.deleteUser();
    } else {
      _localAccounts.remove(_key(user.email));
    }
    _setUser(null);
  }

  Future<void> signOut() async {
    await remote?.signOut();
    _setUser(null);
  }

  void _onRemoteUser(AppUser? user) {
    isLoading = false;
    _setUser(user, force: true);
  }

  void _setUser(AppUser? user, {bool force = false}) {
    if (user == _user && !force) {
      return;
    }
    _user = user;
    notifyListeners();
  }

  AppUser _requireUser() {
    final user = _user;
    if (user == null) {
      throw AuthFailure('not-signed-in');
    }
    return user;
  }

  // ---------------------------------------------------------------------------
  // In-memory accounts
  // ---------------------------------------------------------------------------

  String _key(String email) => email.trim().toLowerCase();

  AppUser _localSignUp(String name, String email, String password) {
    if (_localAccounts.containsKey(_key(email))) {
      throw AuthFailure('email-already-in-use');
    }
    final user = AppUser(
      uid: 'local-user-${++_idCounter}',
      email: email,
      displayName: name,
    );
    _localAccounts[_key(email)] = _LocalAccount(user, password);
    return user;
  }

  AppUser _localSignIn(String email, String password) {
    final account = _localAccounts[_key(email)];
    if (account == null || account.password != password) {
      throw AuthFailure('invalid-credential');
    }
    return account.user;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class _LocalAccount {
  _LocalAccount(this.user, this.password);

  AppUser user;
  String password;
}
