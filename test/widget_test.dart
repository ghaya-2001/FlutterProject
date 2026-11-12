import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foodsaver/main.dart';

void main() {
  testWidgets('splash opens welcome, which leads to login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FoodSaverApp());
    expect(find.byKey(const ValueKey('splash-screen')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2)); // splash minimum duration
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Food Saver'), findsOneWidget);
    expect(find.text("Let's save food together"), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with your food-saving journey'), findsOneWidget);
  });

  testWidgets(
    'sign up, then footer navigation opens fridge, list and profile',
    (WidgetTester tester) async {
      await tester.pumpWidget(const FoodSaverApp());
      await tester.pump(const Duration(seconds: 2)); // splash minimum duration
      await tester.pumpAndSettle();

      // Without Firebase accounts live in memory, so sign-up works in tests.
      final createAccount = find.byKey(
        const ValueKey('welcome-create-account'),
      );
      await tester.ensureVisible(createAccount);
      await tester.tap(createAccount);
      await tester.pumpAndSettle();

      Future<void> fill(String key, String text) => tester.enterText(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(EditableText),
        ),
        text,
      );
      await fill('register-name-field', 'Maya');
      await fill('register-email-field', 'maya@example.com');
      await fill('register-password-field', 'secret12');
      await fill('register-confirm-field', 'secret12');
      final submit = find.byKey(const ValueKey('register-submit-button'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      final fridgeDestination = find.widgetWithText(
        NavigationDestination,
        'Fridge',
      );
      await tester.ensureVisible(fridgeDestination);
      await tester.tap(fridgeDestination);
      await tester.pumpAndSettle();

      expect(find.text('My fridge'), findsOneWidget);

      final listDestination = find.widgetWithText(
        NavigationDestination,
        'List',
      );
      await tester.ensureVisible(listDestination);
      await tester.tap(listDestination);
      await tester.pumpAndSettle();

      expect(find.text('Shopping list'), findsOneWidget);

      final profileDestination = find.widgetWithText(
        NavigationDestination,
        'Profile',
      );
      await tester.ensureVisible(profileDestination);
      await tester.tap(profileDestination);
      await tester.pumpAndSettle();

      expect(find.text('My profile'), findsOneWidget);
      expect(find.text('Maya'), findsOneWidget);
      expect(find.text('maya@example.com'), findsOneWidget);
    },
  );
}
