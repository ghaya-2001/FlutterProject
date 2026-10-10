// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foodsaver/main.dart';

void main() {
  testWidgets('welcome screen navigates to login screen after get started', (WidgetTester tester) async {
    await tester.pumpWidget(const FoodSaverApp());

    expect(find.text('Welcome to Food Saver'), findsOneWidget);
    expect(find.text('Let\'s save food together'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with your food-saving journey'), findsOneWidget);
  });

  testWidgets('footer navigation opens fridge, list and profile screens', (WidgetTester tester) async {
    await tester.pumpWidget(const FoodSaverApp());

    await tester.ensureVisible(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Log In'));
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    final fridgeDestination = find.widgetWithText(NavigationDestination, 'Fridge');
    await tester.ensureVisible(fridgeDestination);
    await tester.tap(fridgeDestination);
    await tester.pumpAndSettle();

    expect(find.text('My fridge'), findsOneWidget);

    final listDestination = find.widgetWithText(NavigationDestination, 'List');
    await tester.ensureVisible(listDestination);
    await tester.tap(listDestination);
    await tester.pumpAndSettle();

    expect(find.text('Shopping list'), findsOneWidget);

    final profileDestination = find.widgetWithText(NavigationDestination, 'Profile');
    await tester.ensureVisible(profileDestination);
    await tester.tap(profileDestination);
    await tester.pumpAndSettle();

    expect(find.text('My profile'), findsOneWidget);
    expect(find.text('Food hero'), findsOneWidget);
  });
}
