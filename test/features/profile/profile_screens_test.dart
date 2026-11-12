import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/auth/data/auth_repository.dart';
import 'package:foodsaver/features/profile/data/user_profile_repository.dart';
import 'package:foodsaver/features/profile/presentation/edit_profile_screen.dart';
import 'package:foodsaver/features/profile/presentation/profile_screen.dart';
import 'package:foodsaver/features/profile/presentation/settings_screen.dart';
import 'package:foodsaver/features/welcome/presentation/welcome_screen.dart';

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final field = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(EditableText),
  );
  await tester.enterText(field, text);
}

void main() {
  late AuthRepository auth;
  late UserProfileRepository profiles;

  setUp(() async {
    auth = AuthRepository();
    profiles = UserProfileRepository(
      auth: auth,
      clock: () => DateTime(2026, 11, 1),
    );
    await auth.signUp(
      displayName: 'Maya Ben',
      email: 'maya@example.com',
      password: 'secret12',
    );
  });

  Widget app(Widget home) => MaterialApp(home: home);

  group('ProfileScreen', () {
    testWidgets('shows the real name and email, not placeholders', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(ProfileScreen(auth: auth, profiles: profiles)),
      );
      expect(find.text('Maya Ben'), findsOneWidget);
      expect(find.text('maya@example.com'), findsOneWidget);
      expect(find.text('Food hero'), findsNothing);
    });

    testWidgets('verify email banner can be dismissed', (tester) async {
      await tester.pumpWidget(
        app(ProfileScreen(auth: auth, profiles: profiles)),
      );
      expect(find.byKey(const ValueKey('verify-email-banner')), findsOneWidget);
      await _tap(tester, 'verify-email-dismiss');
      expect(find.byKey(const ValueKey('verify-email-banner')), findsNothing);
    });

    testWidgets('edit profile changes the name and reports it', (tester) async {
      await tester.pumpWidget(
        app(ProfileScreen(auth: auth, profiles: profiles)),
      );
      await _tap(tester, 'profile-edit-button');
      expect(find.byType(EditProfileScreen), findsOneWidget);
      await _enter(tester, 'edit-profile-name-field', 'Maya Saver');
      await _tap(tester, 'edit-profile-save-button');
      expect(find.text('Profile updated'), findsOneWidget);
      expect(find.text('Maya Saver'), findsOneWidget);
      expect(auth.currentUser?.displayName, 'Maya Saver');
    });

    testWidgets('logout signs out and returns to Welcome', (tester) async {
      await tester.pumpWidget(
        app(ProfileScreen(auth: auth, profiles: profiles)),
      );
      await tester.ensureVisible(find.text('Logout'));
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      await _tap(tester, 'logout-confirm-button');
      expect(auth.isSignedIn, isFalse);
      expect(profiles.profile, isNull);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('EditProfileScreen', () {
    testWidgets('sets the photo from the picker', (tester) async {
      await tester.pumpWidget(
        app(
          EditProfileScreen(
            repository: profiles,
            photoPicker: (_) async => 'aGVsbG8=',
          ),
        ),
      );
      await _tap(tester, 'edit-profile-photo');
      await _tap(tester, 'photo-gallery-option');
      expect(profiles.profile?.photoBase64, 'aGVsbG8=');
    });
  });

  group('SettingsScreen', () {
    testWidgets('notifications switch is saved in the settings', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(SettingsScreen(auth: auth, profiles: profiles)),
      );
      expect(profiles.settings.notificationsEnabled, isTrue);
      await _tap(tester, 'settings-notifications-switch');
      expect(profiles.settings.notificationsEnabled, isFalse);
    });

    testWidgets('changes the password after checking the current one', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(SettingsScreen(auth: auth, profiles: profiles)),
      );
      await _tap(tester, 'settings-change-password');
      await _enter(tester, 'change-password-current', 'wrong-one1');
      await _enter(tester, 'change-password-new', 'newpass12');
      await _enter(tester, 'change-password-confirm', 'newpass12');
      await _tap(tester, 'change-password-submit');
      expect(find.text('Wrong email or password.'), findsOneWidget);

      await _enter(tester, 'change-password-current', 'secret12');
      await _tap(tester, 'change-password-submit');
      expect(find.text('Password changed'), findsOneWidget);
      await auth.signOut();
      await auth.signIn(email: 'maya@example.com', password: 'newpass12');
      expect(auth.isSignedIn, isTrue);
    });

    testWidgets('deletes the account and returns to Welcome', (tester) async {
      await tester.pumpWidget(
        app(SettingsScreen(auth: auth, profiles: profiles)),
      );
      await _tap(tester, 'settings-delete-account');
      await _enter(tester, 'delete-account-password', 'secret12');
      await _tap(tester, 'delete-account-submit');
      expect(auth.isSignedIn, isFalse);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(
        () => auth.signIn(email: 'maya@example.com', password: 'secret12'),
        throwsA(anything),
      );
    });
  });
}
