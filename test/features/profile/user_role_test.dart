import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/auth/data/auth_repository.dart';
import 'package:foodsaver/features/auth/presentation/register_screen.dart';
import 'package:foodsaver/features/home/presentation/home_screen.dart';
import 'package:foodsaver/features/profile/data/user_profile_firestore.dart';
import 'package:foodsaver/features/profile/data/user_profile_repository.dart';
import 'package:foodsaver/features/profile/domain/user_profile.dart';
import 'package:foodsaver/features/profile/domain/user_role.dart';
import 'package:foodsaver/features/profile/domain/user_settings.dart';
import 'package:foodsaver/features/roles/presentation/role_home.dart';
import 'package:foodsaver/features/welcome/presentation/welcome_screen.dart';

/// Stand-in for Firestore: records created profiles and lets the test push
/// the profile document.
class FakeUserProfileFirestore implements UserProfileFirestore {
  final snapshots = <String, StreamController<Map<String, dynamic>?>>{};
  final created = <UserProfile>[];

  StreamController<Map<String, dynamic>?> snapshotsOf(String uid) =>
      snapshots.putIfAbsent(uid, StreamController.broadcast);

  @override
  Stream<Map<String, dynamic>?> watchProfile(String uid) =>
      snapshotsOf(uid).stream;

  @override
  Future<void> createProfileIfMissing(UserProfile profile) async =>
      created.add(profile);

  @override
  Future<void> saveDisplayName(String uid, String displayName) async {}

  @override
  Future<void> savePhoto(String uid, String? photoBase64) async {}

  @override
  Future<void> saveSettings(String uid, UserSettings settings) async {}

  @override
  Future<void> deleteUserData(String uid) async {}
}

void main() {
  group('UserRole', () {
    test('unknown or missing names mean a normal user', () {
      expect(UserRole.fromName('restaurant'), UserRole.restaurant);
      expect(UserRole.fromName('admin'), UserRole.admin);
      expect(UserRole.fromName(null), UserRole.user);
      expect(UserRole.fromName('superuser'), UserRole.user);
    });

    test('admin cannot be chosen at sign-up', () {
      expect(UserRole.selfRegistered, [UserRole.user, UserRole.restaurant]);
    });
  });

  group('role at sign-up', () {
    late AuthRepository auth;
    late UserProfileRepository profiles;

    setUp(() {
      auth = AuthRepository();
      profiles = UserProfileRepository(
        auth: auth,
        clock: () => DateTime(2026, 11, 1),
      );
    });

    test('a normal user is the default', () async {
      await auth.signUp(
        displayName: 'Maya',
        email: 'maya@example.com',
        password: 'secret12',
      );
      expect(profiles.role, UserRole.user);
    });

    test('a restaurant gets its role and business name', () async {
      profiles.prepareSignUp(
        role: UserRole.restaurant,
        businessName: '  Le Jardin  ',
      );
      await auth.signUp(
        displayName: 'Sam',
        email: 'jardin@example.com',
        password: 'secret12',
      );
      expect(profiles.role, UserRole.restaurant);
      expect(profiles.profile?.businessName, 'Le Jardin');
    });

    test('the choice only applies to the next account', () async {
      profiles.prepareSignUp(role: UserRole.restaurant, businessName: 'A');
      await auth.signUp(
        displayName: 'A',
        email: 'a@example.com',
        password: 'secret12',
      );
      await auth.signOut();
      await auth.signUp(
        displayName: 'B',
        email: 'b@example.com',
        password: 'secret12',
      );
      expect(profiles.role, UserRole.user);
      expect(profiles.profile?.businessName, isEmpty);
    });

    test('a failed sign-up does not leak the choice', () async {
      await auth.signUp(
        displayName: 'A',
        email: 'a@example.com',
        password: 'secret12',
      );
      await auth.signOut();
      profiles.prepareSignUp(role: UserRole.restaurant, businessName: 'X');
      profiles.cancelSignUp();
      await auth.signUp(
        displayName: 'B',
        email: 'b@example.com',
        password: 'secret12',
      );
      expect(profiles.role, UserRole.user);
    });

    test('admin is refused', () {
      expect(
        () => profiles.prepareSignUp(role: UserRole.admin),
        throwsArgumentError,
      );
    });

    test('the role is saved with the new profile', () async {
      final remote = FakeUserProfileFirestore();
      final repository = UserProfileRepository(
        auth: auth,
        remote: remote,
        clock: () => DateTime(2026, 11, 1),
      );
      repository.prepareSignUp(role: UserRole.restaurant, businessName: 'R');
      await auth.signUp(
        displayName: 'R',
        email: 'r@example.com',
        password: 'secret12',
      );
      expect(remote.created.single.role, UserRole.restaurant);
      expect(remote.created.single.businessName, 'R');
    });
  });

  group('role in the profile document', () {
    test('is read from Firestore, and whenReady waits for it', () async {
      final auth = AuthRepository();
      final remote = FakeUserProfileFirestore();
      final profiles = UserProfileRepository(auth: auth, remote: remote);
      await auth.signUp(
        displayName: 'Root',
        email: 'root@example.com',
        password: 'secret12',
      );
      expect(profiles.isLoading, isTrue);

      var ready = false;
      final waiting = profiles.whenReady().then((_) => ready = true);
      await Future<void>.delayed(Duration.zero);
      expect(ready, isFalse);

      remote.snapshotsOf(auth.currentUser!.uid).add({
        'displayName': 'Root',
        'email': 'root@example.com',
        'role': 'admin',
      });
      await waiting;
      expect(profiles.role, UserRole.admin);
    });
  });

  group('RoleHome', () {
    Future<(AuthRepository, UserProfileRepository)> signedIn(
      UserRole role, {
      String businessName = '',
    }) async {
      final auth = AuthRepository();
      final profiles = UserProfileRepository(auth: auth);
      if (role != UserRole.user) {
        profiles.prepareSignUp(role: role, businessName: businessName);
      }
      await auth.signUp(
        displayName: 'Sam',
        email: 'sam@example.com',
        password: 'secret12',
      );
      return (auth, profiles);
    }

    testWidgets('a normal user gets the app', (tester) async {
      final (auth, profiles) = await signedIn(UserRole.user);
      await tester.pumpWidget(
        MaterialApp(
          home: RoleHome(profiles: profiles, auth: auth),
        ),
      );
      expect(find.byType(FoodSaverHomePage), findsOneWidget);
    });

    testWidgets('a restaurant gets its own shell, without the fridge', (
      tester,
    ) async {
      final (auth, profiles) = await signedIn(
        UserRole.restaurant,
        businessName: 'Le Jardin',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RoleHome(profiles: profiles, auth: auth),
        ),
      );
      expect(find.byKey(const ValueKey('restaurant-shell')), findsOneWidget);
      expect(find.text('Available donations'), findsOneWidget);
      expect(find.byType(FoodSaverHomePage), findsNothing);
      expect(find.text('Fridge'), findsNothing);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Le Jardin'), findsOneWidget);
      expect(find.text('Restaurant'), findsOneWidget);
    });

    testWidgets('an admin gets the pending requests shell', (tester) async {
      final auth = AuthRepository();
      final remote = FakeUserProfileFirestore();
      final profiles = UserProfileRepository(auth: auth, remote: remote);
      await auth.signUp(
        displayName: 'Root',
        email: 'root@example.com',
        password: 'secret12',
      );
      remote.snapshotsOf(auth.currentUser!.uid).add({
        'displayName': 'Root',
        'email': 'root@example.com',
        'role': 'admin',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: RoleHome(profiles: profiles, auth: auth),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('admin-shell')), findsOneWidget);
      expect(find.text('Pending requests'), findsOneWidget);
    });

    testWidgets('logout from a role shell returns to Welcome', (tester) async {
      final (auth, profiles) = await signedIn(
        UserRole.restaurant,
        businessName: 'Le Jardin',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RoleHome(profiles: profiles, auth: auth),
        ),
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('role-profile-logout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('logout-confirm-button')));
      await tester.pumpAndSettle();
      expect(auth.isSignedIn, isFalse);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('RegisterScreen role choice', () {
    Future<void> fill(WidgetTester tester, String key, String text) async {
      final field = find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(EditableText),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, text);
    }

    testWidgets('a restaurant must give its name and lands in its shell', (
      tester,
    ) async {
      final auth = AuthRepository();
      final profiles = UserProfileRepository(auth: auth);
      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(repository: auth, profiles: profiles),
        ),
      );
      expect(
        find.byKey(const ValueKey('register-business-field')),
        findsNothing,
      );

      await tester.tap(find.text('Restaurant'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('register-business-field')),
        findsOneWidget,
      );

      await fill(tester, 'register-name-field', 'Sam');
      await fill(tester, 'register-email-field', 'sam@example.com');
      await fill(tester, 'register-password-field', 'secret12');
      await fill(tester, 'register-confirm-field', 'secret12');
      final submit = find.byKey(const ValueKey('register-submit-button'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Enter the name of your restaurant.'), findsOneWidget);
      expect(auth.isSignedIn, isFalse);

      await fill(tester, 'register-business-field', 'Le Jardin');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(profiles.role, UserRole.restaurant);
      expect(find.byKey(const ValueKey('restaurant-shell')), findsOneWidget);
    });

    testWidgets('admin is not offered', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(
            repository: AuthRepository(),
            profiles: UserProfileRepository(auth: AuthRepository()),
          ),
        ),
      );
      expect(find.text('Admin'), findsNothing);
      expect(find.text('Individual'), findsOneWidget);
    });
  });
}
