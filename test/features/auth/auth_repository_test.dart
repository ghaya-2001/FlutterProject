import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/auth/data/auth_firebase.dart';
import 'package:foodsaver/features/auth/data/auth_repository.dart';
import 'package:foodsaver/features/auth/domain/app_user.dart';
import 'package:foodsaver/features/auth/domain/auth_failure.dart';

/// Stand-in for Firebase Auth that records calls and lets the test push
/// account changes, as Firebase does with `userChanges()`.
class FakeAuthFirebase implements AuthFirebase {
  FakeAuthFirebase({this.user});

  AppUser? user;
  final changes = StreamController<AppUser?>.broadcast();
  final calls = <String>[];

  /// When set, the next call throws this error code.
  String? failWith;

  @override
  AppUser? get currentUser => user;

  @override
  Stream<AppUser?> watchUser() => changes.stream;

  Future<T> _call<T>(String name, T Function() result) async {
    calls.add(name);
    final code = failWith;
    if (code != null) {
      failWith = null;
      throw AuthFailure(code);
    }
    return result();
  }

  @override
  Future<AppUser> signUp({
    required String displayName,
    required String email,
    required String password,
  }) => _call(
    'signUp $displayName $email',
    () => user = AppUser(uid: 'uid-1', email: email, displayName: displayName),
  );

  @override
  Future<AppUser> signIn({required String email, required String password}) =>
      _call('signIn $email', () => user = AppUser(uid: 'uid-1', email: email));

  @override
  Future<void> sendPasswordReset(String email) => _call('reset $email', () {});

  @override
  Future<void> sendEmailVerification() => _call('verify', () {});

  @override
  Future<AppUser> reload() =>
      _call('reload', () => user = user!.copyWith(emailVerified: true));

  @override
  Future<void> updateDisplayName(String displayName) =>
      _call('name $displayName', () {});

  @override
  Future<void> reauthenticate(String password) =>
      _call('reauth $password', () {});

  @override
  Future<void> updatePassword(String newPassword) =>
      _call('password $newPassword', () {});

  @override
  Future<void> deleteUser() => _call('delete', () => user = null);

  @override
  Future<void> signOut() => _call('signOut', () => user = null);
}

void main() {
  group('in memory (no Firebase)', () {
    late AuthRepository auth;

    setUp(() => auth = AuthRepository());

    test('starts signed out and not loading', () {
      expect(auth.isSignedIn, isFalse);
      expect(auth.isLoading, isFalse);
    });

    test('sign up signs in, trims the name and email, and notifies', () async {
      var notified = 0;
      auth.addListener(() => notified++);

      final user = await auth.signUp(
        displayName: '  Maya ',
        email: ' maya@example.com ',
        password: 'abc123',
      );

      expect(user.displayName, 'Maya');
      expect(user.email, 'maya@example.com');
      expect(auth.currentUser, user);
      expect(notified, 1);
    });

    test('rejects a second account with the same email', () async {
      await auth.signUp(displayName: 'A', email: 'a@x.com', password: 'abc123');
      await auth.signOut();

      expect(
        () => auth.signUp(displayName: 'B', email: 'A@X.com', password: 'p1'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            'email-already-in-use',
          ),
        ),
      );
    });

    test('sign in checks the password; sign out clears the user', () async {
      await auth.signUp(displayName: 'A', email: 'a@x.com', password: 'abc123');
      await auth.signOut();
      expect(auth.currentUser, isNull);

      await expectLater(
        auth.signIn(email: 'a@x.com', password: 'wrong'),
        throwsA(isA<AuthFailure>()),
      );
      final user = await auth.signIn(email: 'A@x.com ', password: 'abc123');
      expect(user.displayName, 'A');
      expect(auth.isSignedIn, isTrue);
    });

    test('change password requires the current password', () async {
      await auth.signUp(displayName: 'A', email: 'a@x.com', password: 'abc123');

      await expectLater(
        auth.changePassword(currentPassword: 'nope', newPassword: 'xyz789'),
        throwsA(
          isA<AuthFailure>().having((f) => f.code, 'code', 'wrong-password'),
        ),
      );
      await auth.changePassword(
        currentPassword: 'abc123',
        newPassword: 'xyz789',
      );
      await auth.signOut();

      await expectLater(
        auth.signIn(email: 'a@x.com', password: 'abc123'),
        throwsA(isA<AuthFailure>()),
      );
      await auth.signIn(email: 'a@x.com', password: 'xyz789');
    });

    test('update name and delete account', () async {
      await auth.signUp(displayName: 'A', email: 'a@x.com', password: 'abc123');
      await auth.updateDisplayName(' Maya ');
      expect(auth.currentUser!.displayName, 'Maya');

      await auth.deleteAccount();
      expect(auth.isSignedIn, isFalse);
      await expectLater(
        auth.signIn(email: 'a@x.com', password: 'abc123'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('actions that need an account fail when signed out', () {
      expect(
        () => auth.updateDisplayName('Maya'),
        throwsA(
          isA<AuthFailure>().having((f) => f.code, 'code', 'not-signed-in'),
        ),
      );
      expect(auth.deleteAccount, throwsA(isA<AuthFailure>()));
    });
  });

  group('with Firebase', () {
    test('loads until Firebase reports the signed-in user', () async {
      final remote = FakeAuthFirebase();
      final auth = AuthRepository(remote: remote);
      expect(auth.isLoading, isTrue);

      const user = AppUser(uid: 'uid-1', email: 'a@x.com');
      remote.changes.add(user);
      await pumpEventQueue();

      expect(auth.isLoading, isFalse);
      expect(auth.currentUser, user);

      remote.changes.add(null);
      await pumpEventQueue();
      expect(auth.isSignedIn, isFalse);
    });

    test('a restored session is available right away', () {
      const user = AppUser(uid: 'uid-1', email: 'a@x.com');
      final auth = AuthRepository(remote: FakeAuthFirebase(user: user));

      expect(auth.isLoading, isFalse);
      expect(auth.currentUser, user);
    });

    test('passes trimmed values to Firebase', () async {
      final remote = FakeAuthFirebase();
      final auth = AuthRepository(remote: remote);

      await auth.signUp(
        displayName: ' Maya ',
        email: ' maya@x.com ',
        password: 'abc123',
      );
      await auth.sendPasswordReset(' maya@x.com ');

      expect(remote.calls, ['signUp Maya maya@x.com', 'reset maya@x.com']);
      expect(auth.currentUser!.displayName, 'Maya');
    });

    test('change password re-authenticates first', () async {
      final remote = FakeAuthFirebase(
        user: const AppUser(uid: 'uid-1', email: 'a@x.com'),
      );
      final auth = AuthRepository(remote: remote);

      await auth.changePassword(currentPassword: 'old1', newPassword: 'new1');

      expect(remote.calls, ['reauth old1', 'password new1']);
    });

    test('a failed re-authentication stops the password change', () async {
      final remote = FakeAuthFirebase(
        user: const AppUser(uid: 'uid-1', email: 'a@x.com'),
      )..failWith = 'wrong-password';
      final auth = AuthRepository(remote: remote);

      await expectLater(
        auth.changePassword(currentPassword: 'bad', newPassword: 'new1'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            'Wrong email or password.',
          ),
        ),
      );
      expect(remote.calls, ['reauth bad']);
    });

    test('reload picks up the verified email', () async {
      final remote = FakeAuthFirebase(
        user: const AppUser(uid: 'uid-1', email: 'a@x.com'),
      );
      final auth = AuthRepository(remote: remote);

      await auth.reloadUser();

      expect(auth.currentUser!.emailVerified, isTrue);
    });

    test('sign out tells Firebase and clears the user', () async {
      final remote = FakeAuthFirebase(
        user: const AppUser(uid: 'uid-1', email: 'a@x.com'),
      );
      final auth = AuthRepository(remote: remote);

      await auth.signOut();

      expect(remote.calls, ['signOut']);
      expect(auth.currentUser, isNull);
    });
  });
}
