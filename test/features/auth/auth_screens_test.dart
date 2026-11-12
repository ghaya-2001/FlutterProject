import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/auth/data/auth_repository.dart';
import 'package:foodsaver/features/auth/presentation/login_screen.dart';
import 'package:foodsaver/features/auth/presentation/register_screen.dart';
import 'package:foodsaver/features/auth/presentation/reset_password_screen.dart';
import 'package:foodsaver/features/auth/presentation/splash_screen.dart';
import 'package:foodsaver/features/home/presentation/home_screen.dart';
import 'package:foodsaver/features/welcome/presentation/welcome_screen.dart';

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(EditableText),
  );
  final target = field.evaluate().isEmpty ? find.byKey(ValueKey(key)) : field;
  await tester.ensureVisible(target);
  await tester.enterText(target, text);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  late AuthRepository auth;

  setUp(() {
    auth = AuthRepository();
  });

  group('SplashScreen', () {
    testWidgets('opens Welcome when signed out', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            repository: auth,
            minimumDuration: const Duration(milliseconds: 10),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('splash-screen')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('opens Home when signed in', (tester) async {
      await auth.signUp(
        displayName: 'Maya',
        email: 'maya@example.com',
        password: 'secret12',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            repository: auth,
            minimumDuration: const Duration(milliseconds: 10),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FoodSaverHomePage), findsOneWidget);
    });
  });

  group('LoginScreen', () {
    testWidgets('validates the form before signing in', (tester) async {
      await tester.pumpWidget(MaterialApp(home: LoginScreen(repository: auth)));
      await _tap(tester, 'login-submit-button');
      expect(find.text('Enter your email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(auth.isSignedIn, isFalse);
    });

    testWidgets('shows the error for wrong credentials', (tester) async {
      await tester.pumpWidget(MaterialApp(home: LoginScreen(repository: auth)));
      await _type(tester, 'login-email-field', 'nobody@example.com');
      await _type(tester, 'login-password-field', 'whatever1');
      await _tap(tester, 'login-submit-button');
      expect(find.text('Wrong email or password.'), findsOneWidget);
      expect(find.byType(FoodSaverHomePage), findsNothing);
    });

    testWidgets('signs in and opens Home', (tester) async {
      await auth.signUp(
        displayName: 'Maya',
        email: 'maya@example.com',
        password: 'secret12',
      );
      await auth.signOut();
      await tester.pumpWidget(MaterialApp(home: LoginScreen(repository: auth)));
      await _type(tester, 'login-email-field', 'maya@example.com');
      await _type(tester, 'login-password-field', 'secret12');
      await _tap(tester, 'login-submit-button');
      expect(auth.currentUser?.displayName, 'Maya');
      expect(find.byType(FoodSaverHomePage), findsOneWidget);
    });

    testWidgets('links to Register and Reset password', (tester) async {
      await tester.pumpWidget(MaterialApp(home: LoginScreen(repository: auth)));
      await _tap(tester, 'login-signup-button');
      expect(find.byType(RegisterScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      await _tap(tester, 'login-forgot-button');
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
    });
  });

  group('RegisterScreen', () {
    testWidgets('rejects mismatching passwords', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RegisterScreen(repository: auth)),
      );
      await _type(tester, 'register-name-field', 'Maya');
      await _type(tester, 'register-email-field', 'maya@example.com');
      await _type(tester, 'register-password-field', 'secret12');
      await _type(tester, 'register-confirm-field', 'secret13');
      await _tap(tester, 'register-submit-button');
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(auth.isSignedIn, isFalse);
    });

    testWidgets('creates the account and opens Home', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RegisterScreen(repository: auth)),
      );
      await _type(tester, 'register-name-field', 'Maya');
      await _type(tester, 'register-email-field', 'maya@example.com');
      await _type(tester, 'register-password-field', 'secret12');
      await _type(tester, 'register-confirm-field', 'secret12');
      await _tap(tester, 'register-submit-button');
      expect(auth.currentUser?.displayName, 'Maya');
      expect(find.byType(FoodSaverHomePage), findsOneWidget);
    });

    testWidgets('shows the error when the email is taken', (tester) async {
      await auth.signUp(
        displayName: 'Maya',
        email: 'maya@example.com',
        password: 'secret12',
      );
      await auth.signOut();
      await tester.pumpWidget(
        MaterialApp(home: RegisterScreen(repository: auth)),
      );
      await _type(tester, 'register-name-field', 'Other');
      await _type(tester, 'register-email-field', 'maya@example.com');
      await _type(tester, 'register-password-field', 'secret12');
      await _type(tester, 'register-confirm-field', 'secret12');
      await _tap(tester, 'register-submit-button');
      expect(
        find.text('An account already exists with this email.'),
        findsOneWidget,
      );
    });
  });

  group('ResetPasswordScreen', () {
    testWidgets('confirms without revealing whether the email exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: ResetPasswordScreen(repository: auth)),
      );
      await _tap(tester, 'reset-submit-button');
      expect(find.text('Enter your email.'), findsOneWidget);

      await _type(tester, 'reset-email-field', 'nobody@example.com');
      await _tap(tester, 'reset-submit-button');
      expect(find.byKey(const ValueKey('reset-sent-message')), findsOneWidget);
    });
  });
}
