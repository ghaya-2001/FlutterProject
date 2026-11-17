import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/donations/data/donation_repository.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/list/data/shopping_list_repository.dart';
import 'package:foodsaver/features/notifications/data/notification_repository.dart';
import 'package:foodsaver/features/recipes/data/health_profile_repository.dart';
import 'package:foodsaver/features/recipes/data/saved_recipes_repository.dart';
import 'package:foodsaver/features/recipes/domain/extra_recipes.dart';
import 'package:foodsaver/features/recipes/domain/health_goal.dart';
import 'package:foodsaver/features/recipes/presentation/recipe_book_screen.dart';
import 'package:foodsaver/features/recipes/presentation/recipe_view_screen.dart';
import 'package:foodsaver/features/statistics/presentation/statistics_screen.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late FridgeRepository fridge;
  late SavedRecipesRepository saved;
  late ShoppingListRepository shopping;
  late HealthProfileRepository health;

  setUp(() {
    fridge = FridgeRepository(clock: () => today);
    saved = SavedRecipesRepository(clock: () => today);
    shopping = ShoppingListRepository();
    health = HealthProfileRepository(clock: () => today);
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  RecipeBookScreen book() => RecipeBookScreen(
    fridge: fridge,
    savedRecipes: saved,
    shopping: shopping,
    healthProfile: health,
  );

  testWidgets('a recipe shows its calories, macros and tags', (tester) async {
    health.setGoal(HealthGoal.buildMuscle);
    await pump(
      tester,
      RecipeViewScreen(
        recipeId: 'chicken-curry',
        fridge: fridge,
        savedRecipes: saved,
        shopping: shopping,
        healthProfile: health,
      ),
    );
    expect(find.text('Nutrition'), findsOneWidget);
    expect(textOf(tester, 'recipe-view-kcal'), '560');
    expect(find.text('Rich'), findsOneWidget);
    expect(find.text('40 g'), findsOneWidget); // protein
    expect(find.text('High protein'), findsOneWidget);
    expect(find.text('Gluten free'), findsOneWidget);
    expect(find.text('Vegetarian'), findsNothing);
    expect(find.text('Fits your goal'), findsOneWidget);
  });

  testWidgets('recipe cards show their calories', (tester) async {
    await pump(tester, book());
    await tester.enterText(
      find.byKey(const ValueKey('recipes-search-field')),
      'tomato soup',
    );
    await tester.pump();
    expect(find.text('180 kcal'), findsOneWidget);
  });

  testWidgets('the vegetarian filter hides meat recipes', (tester) async {
    await pump(tester, book());
    await tap(tester, 'recipes-filter-vegetarian');
    expect(find.text('Yogurt chicken curry'), findsNothing);
    expect(find.text('Chicken wraps'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Lentil & spinach dal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Lentil & spinach dal'), findsOneWidget);
  });

  testWidgets('choosing a goal from the Recipes screen', (tester) async {
    await pump(tester, book());
    expect(
      find.text('Set a health goal to get matching suggestions'),
      findsOneWidget,
    );
    await tap(tester, 'recipes-goal-banner');
    expect(find.text('Your health goal'), findsOneWidget);
    await tap(tester, 'health-goal-loseWeight');

    expect(health.goal, HealthGoal.loseWeight);
    expect(find.textContaining('Goal: Lose weight'), findsOneWidget);
    expect(find.text('Fits your goal'), findsWidgets);
  });

  group('StatisticsScreen health sections', () {
    late DonationRepository donations;

    setUp(() {
      donations = DonationRepository(
        seed: false,
        fridge: fridge,
        notifications: NotificationRepository(fridge: fridge),
      );
    });

    Widget statistics() => StatisticsScreen(
      fridge: fridge,
      donations: donations,
      savedRecipes: saved,
      healthProfile: health,
    );

    testWidgets('no meal cooked: empty nutrition, challenges at 0', (
      tester,
    ) async {
      await pump(tester, statistics());
      expect(find.text('Healthy eating'), findsOneWidget);
      expect(find.textContaining('No meal cooked'), findsOneWidget);
      expect(textOf(tester, 'stats-challenges-done'), '0/5 done');
      expect(
        find.byKey(const ValueKey('stats-challenge-veggie')),
        findsOneWidget,
      );
    });

    testWidgets('cooking a recipe adds its calories and challenge progress', (
      tester,
    ) async {
      health.setGoal(HealthGoal.loseWeight);
      final tomatoes = fridge.items.firstWhere((i) => i.name == 'Tomatoes');
      fridge.cookRecipe(recipeById('shakshuka')!, {tomatoes.id: 0.5});

      await pump(tester, statistics());
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('stats-kcal')),
          matching: find.text('290'),
        ),
        findsOneWidget,
      );
      expect(
        textOf(tester, 'stats-goal-meals'),
        '1 of 1 meal fits your goal (lose weight)',
      );
      expect(find.text('1/3'), findsNWidgets(2)); // veggie + light
    });

    testWidgets('the goal can be changed from Statistics', (tester) async {
      await pump(tester, statistics());
      await tap(tester, 'stats-goal');
      await tap(tester, 'health-goal-buildMuscle');
      expect(health.goal, HealthGoal.buildMuscle);
      expect(find.text('Build muscle'), findsOneWidget);
    });
  });
}
