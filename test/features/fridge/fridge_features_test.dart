import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/fridge/data/fridge_firestore.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/fridge/domain/food_category.dart';
import 'package:foodsaver/features/fridge/domain/fridge_event.dart';
import 'package:foodsaver/features/fridge/domain/recipes.dart';
import 'package:foodsaver/features/fridge/domain/shelf_life.dart';
import 'package:foodsaver/features/fridge/presentation/fridge_screen.dart';
import 'package:foodsaver/features/fridge/presentation/fridge_stats_screen.dart';
import 'package:foodsaver/features/fridge/presentation/import_groceries_screen.dart';
import 'package:foodsaver/features/fridge/presentation/recipes_screen.dart';
import 'package:foodsaver/features/list/data/shopping_list_repository.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late FridgeRepository fridge;

  FoodCategory category(String name) => fridge.categoryNamed(name)!;

  setUp(() {
    // Seeded: Spinach (2 days), Yogurt (today), Tomatoes (3), Milk (5),
    // Lemon (7), Chicken breast (1), Eggs (14).
    fridge = FridgeRepository(clock: () => today);
  });

  void setView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  group('recipe suggestions', () {
    test('recipes saving the most expiring foods come first', () {
      final matches = fridge.recipeSuggestions;
      final best = matches.first;
      expect(best.recipe.id, 'chicken-salad');
      expect(best.canCook, isTrue);
      expect(best.urgentCount, greaterThanOrEqualTo(2));
      for (var i = 1; i < matches.length; i++) {
        expect(
          matches[i - 1].urgentCount,
          greaterThanOrEqualTo(matches[i].urgentCount),
        );
      }
    });

    test('missing ingredients are listed, optional ones never', () {
      final chickenRice = fridge.recipeSuggestions.firstWhere(
        (m) => m.recipe.id == 'lemon-chicken-rice',
      );
      expect(chickenRice.missing.map((i) => i.name), ['Rice']);
      expect(chickenRice.coverage, closeTo(2 / 3, 0.001));
    });

    test('ingredient keywords match words of the food name', () {
      final item = fridge.addFood(
        name: 'Cherry tomatoes',
        category: category('Vegetables'),
        quantity: 1,
        unit: 'pack',
        expiryDate: today,
      );
      const tomato = RecipeIngredient(
        'Tomatoes',
        keywords: ['tomato'],
        category: 'Vegetables',
      );
      expect(tomato.matches(item), isTrue);
    });

    test('expired foods are never suggested', () {
      final empty = FridgeRepository(seed: false, clock: () => today);
      empty.addFood(
        name: 'Eggs',
        category: otherFoodCategory,
        quantity: 6,
        unit: 'pcs',
        expiryDate: today.subtract(const Duration(days: 1)),
      );
      expect(empty.recipeSuggestions, isEmpty);
    });

    test('cookRecipe uses the foods and records one cooking session', () {
      final match = fridge.recipeSuggestions.first;
      final amounts = {
        for (final food in match.used.values) food.id: defaultCookAmount(food),
      };
      final before = {
        for (final food in match.used.values) food.id: food.quantity,
      };

      fridge.cookRecipe(match.recipe, amounts);

      for (final entry in amounts.entries) {
        final left = fridge.itemById(entry.key)?.quantity ?? 0;
        expect(left, closeTo(before[entry.key]! - entry.value, 0.001));
      }
      final events = fridge.history;
      expect(events, hasLength(amounts.length));
      expect(events.every((e) => e.recipe == match.recipe.name), isTrue);
      expect(events.map((e) => e.at).toSet(), hasLength(1));
      expect(fridge.achievements.firstWhere((a) => a.id == 'chef').current, 1);
      expect(() => fridge.cookRecipe(match.recipe, {}), throwsArgumentError);
    });
  });

  group('achievements', () {
    test('everything is locked without history', () {
      final empty = FridgeRepository(seed: false, clock: () => today);
      expect(empty.achievements.where((a) => a.isUnlocked), isEmpty);
    });

    test('eating on the last day counts as a rescue', () {
      final yogurt = fridge.items.firstWhere((i) => i.name == 'Yogurt');
      final eggs = fridge.items.firstWhere((i) => i.name == 'Eggs');
      fridge.consume(yogurt.id, 1);
      fridge.consume(eggs.id, 1);

      expect(fridge.history.first.daysLeft, 14);
      final achievements = fridge.achievements;
      final rescue = achievements.firstWhere((a) => a.id == 'last-minute');
      expect(rescue.current, 1);
      expect(rescue.isUnlocked, isFalse);
      final firstBite = achievements.firstWhere((a) => a.id == 'first-bite');
      expect(firstBite.isUnlocked, isTrue);
      // Unlocked badges are shown first.
      expect(achievements.first.isUnlocked, isTrue);
    });
  });

  group('groceries from the shopping list', () {
    test('suggested expiry follows the shelf life of the category', () {
      expect(
        suggestedExpiry(category('Meat & Fish'), today),
        DateTime(2026, 10, 26),
      );
      expect(suggestedExpiry(otherFoodCategory, today), DateTime(2026, 11, 7));
    });

    test('a bought item is imported only once', () {
      final grocery = GroceryImport(
        shoppingItemId: 'item-1',
        name: ' Butter ',
        category: category('Dairy'),
        quantity: 2,
        unit: 'pcs',
        expiryDate: DateTime(2026, 11, 1, 15),
      );
      final total = fridge.totalCount;

      final added = fridge.importGroceries([grocery]);
      expect(added.single.name, 'Butter');
      expect(added.single.expiryDate, DateTime(2026, 11, 1));
      expect(fridge.isImported('item-1'), isTrue);
      expect(fridge.importGroceries([grocery]), isEmpty);
      expect(fridge.totalCount, total + 1);
    });

    test('event details survive the Firestore round trip', () {
      final event = FridgeEvent(
        id: 'event-1',
        type: FridgeEventType.consumed,
        foodName: 'Eggs',
        category: otherFoodCategory,
        quantity: 2,
        unit: 'pcs',
        at: today,
        daysLeft: 1,
        recipe: 'Shakshuka',
      );
      final back = fridgeEventFromMap({
        ...fridgeEventToMap(event),
        'id': event.id,
      }, (_) => otherFoodCategory);
      expect(back.daysLeft, 1);
      expect(back.recipe, 'Shakshuka');
    });
  });

  group('screens', () {
    late ShoppingListRepository shopping;

    setUp(() {
      shopping = ShoppingListRepository(seed: false);
    });

    testWidgets('fridge shows the Cook now and Groceries actions', (
      tester,
    ) async {
      setView(tester);
      final list = shopping.createList('Weekly');
      final cheese = shopping.addItem(
        list.id,
        name: 'Cheese',
        category: shopping.categoryNamed('Dairy')!,
      );
      shopping.toggleBought(list.id, cheese.id);

      await tester.pumpWidget(
        MaterialApp(
          home: FridgeScreen(repository: fridge, shoppingRepository: shopping),
        ),
      );

      expect(find.byKey(const ValueKey('cook-now-action')), findsOneWidget);
      expect(find.text('1 bought to add'), findsOneWidget);
    });

    testWidgets('new screens fit a small phone without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1380);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final list = shopping.createList('Weekly groceries and more');
      final item = shopping.addItem(
        list.id,
        name: 'Extra creamy Greek yogurt',
        category: shopping.categoryNamed('Dairy')!,
      );
      shopping.toggleBought(list.id, item.id);
      fridge.consume(fridge.items.first.id, 0.5);

      final screens = <Widget>[
        FridgeScreen(repository: fridge, shoppingRepository: shopping),
        RecipesScreen(repository: fridge, shoppingRepository: shopping),
        RecipeDetailsScreen(
          repository: fridge,
          recipeId: 'creamy-spinach-pasta',
          shoppingRepository: shopping,
        ),
        ImportGroceriesScreen(repository: fridge, shoppingRepository: shopping),
        FridgeStatsScreen(repository: fridge),
      ];
      for (final screen in screens) {
        await tester.pumpWidget(MaterialApp(home: screen));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('cook a suggested recipe', (tester) async {
      setView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: RecipesScreen(repository: fridge, shoppingRepository: shopping),
        ),
      );

      await tester.tap(find.text('Chicken & tomato salad'));
      await tester.pumpAndSettle();
      expect(find.text('From your fridge'), findsOneWidget);

      final cooked = find.byKey(const ValueKey('cooked-button'));
      await tester.scrollUntilVisible(cooked, 200);
      await tester.tap(cooked);
      await tester.pumpAndSettle();

      expect(fridge.history, isNotEmpty);
      expect(fridge.history.first.recipe, 'Chicken & tomato salad');
      expect(find.textContaining('saved from waste'), findsOneWidget);
    });

    testWidgets('missing ingredients go to the shopping list', (tester) async {
      setView(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: RecipeDetailsScreen(
            repository: fridge,
            recipeId: 'lemon-chicken-rice',
            shoppingRepository: shopping,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('add-missing-button')));
      await tester.pump();

      final list = shopping.lists.single;
      expect(list.name, 'Recipe ingredients');
      expect(list.items.single.name, 'Rice');
      expect(list.items.single.category.name, 'Pantry');
    });

    testWidgets('bought groceries are added to the fridge', (tester) async {
      setView(tester);
      final list = shopping.createList('Weekly');
      final butter = shopping.addItem(
        list.id,
        name: 'Butter',
        category: shopping.categoryNamed('Dairy')!,
        quantity: 2,
      );
      final soap = shopping.addItem(
        list.id,
        name: 'Soap',
        category: shopping.categoryNamed('Household')!,
      );
      shopping.addItem(
        list.id,
        name: 'Bread',
        category: shopping.categoryNamed('Bakery')!,
      );
      shopping.toggleBought(list.id, butter.id);
      shopping.toggleBought(list.id, soap.id);

      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (context) => ImportGroceriesScreen(
                      repository: fridge,
                      shoppingRepository: shopping,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Not bought (Bread) and not food (Soap) are not offered.
      expect(find.text('Butter'), findsOneWidget);
      expect(find.text('Bread'), findsNothing);
      expect(find.text('Soap'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('import-groceries-button')));
      await tester.pumpAndSettle();

      expect(result, '1 food(s) added to your fridge');
      final added = fridge.items.firstWhere((i) => i.name == 'Butter');
      expect(added.quantity, 2);
      expect(added.category.name, 'Dairy');
      expect(fridge.isImported(butter.id), isTrue);
      expect(ImportGroceriesScreen.pendingCount(fridge, shopping), 0);
    });
  });
}
