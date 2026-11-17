import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/auth/data/auth_repository.dart';
import 'package:foodsaver/features/donations/data/donation_repository.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/home/presentation/home_screen.dart';
import 'package:foodsaver/features/notifications/data/notification_repository.dart';
import 'package:foodsaver/features/profile/data/user_profile_repository.dart';
import 'package:foodsaver/features/recipes/data/saved_recipes_repository.dart';

void main() {
  final morning = DateTime(2026, 10, 24, 10, 30);
  late FridgeRepository fridge;
  late DonationRepository donations;
  late SavedRecipesRepository saved;
  late AuthRepository auth;
  late UserProfileRepository profiles;

  setUp(() async {
    fridge = FridgeRepository(clock: () => morning);
    donations = DonationRepository(
      seed: false,
      fridge: fridge,
      notifications: NotificationRepository(fridge: fridge),
    );
    saved = SavedRecipesRepository(clock: () => morning);
    auth = AuthRepository();
    profiles = UserProfileRepository(auth: auth, clock: () => morning);
    await auth.signUp(
      displayName: 'Shayma Ayari',
      email: 'shayma@example.com',
      password: 'secret12',
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodSaverHomePage(
          fridge: fridge,
          donations: donations,
          savedRecipes: saved,
          profiles: profiles,
        ),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('greets the user by first name with real counters', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Good morning,'), findsOneWidget);
    expect(find.text('Shayma'), findsOneWidget);
    expect(find.text('Maya'), findsNothing);
    expect(find.text('7 items'), findsOneWidget); // seeded fridge
    expect(find.textContaining('ready to cook'), findsOneWidget);
    expect(find.text('No meals saved yet this week'), findsOneWidget);
    expect(find.text('12 meals protected this week'), findsNothing);
    expect(find.text('Cook before it expires'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-notifications-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-expiring-view-all')),
      findsOneWidget,
    );
  });

  testWidgets('meals saved this week follow the fridge history', (
    tester,
  ) async {
    final tomatoes = fridge.items.firstWhere((i) => i.name == 'Tomatoes');
    fridge.consume(tomatoes.id, 1);
    saved.save('pancakes');
    await pump(tester);
    expect(find.text('3 meals saved this week'), findsOneWidget);
    expect(find.text('1 saved recipe'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('cards open Recipes, Statistics and Saved recipes', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, 'home-recipes-card');
    expect(find.text('Suggested for you'), findsOneWidget);
    await goBack(tester);

    await tap(tester, 'home-meals-card');
    expect(find.text('Statistics'), findsWidgets);
    expect(find.text('How is this calculated?'), findsOneWidget);
    await goBack(tester);

    await tap(tester, 'home-saved-card');
    expect(find.text('Saved recipes'), findsOneWidget);
    await goBack(tester);

    await tap(tester, 'home-recipe-idea');
    expect(find.text('Ingredients'), findsOneWidget);
  });

  test('greetingFor', () {
    expect(greetingFor(DateTime(2026, 1, 1, 8)), 'Good morning');
    expect(greetingFor(DateTime(2026, 1, 1, 13)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 1, 1, 21)), 'Good evening');
  });
}

Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
  await tester.pumpAndSettle();
}
