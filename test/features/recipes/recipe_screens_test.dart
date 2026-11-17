import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/fridge/domain/fridge_event.dart';
import 'package:foodsaver/features/list/data/shopping_list_repository.dart';
import 'package:foodsaver/features/recipes/data/saved_recipes_repository.dart';
import 'package:foodsaver/features/recipes/domain/saved_recipe.dart';
import 'package:foodsaver/features/recipes/presentation/recipe_book_screen.dart';
import 'package:foodsaver/features/recipes/presentation/recipe_view_screen.dart';
import 'package:foodsaver/features/recipes/presentation/saved_recipes_screen.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late FridgeRepository fridge;
  late SavedRecipesRepository saved;
  late ShoppingListRepository shopping;

  setUp(() {
    fridge = FridgeRepository(clock: () => today);
    saved = SavedRecipesRepository(clock: () => today);
    shopping = ShoppingListRepository();
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  RecipeBookScreen book() =>
      RecipeBookScreen(fridge: fridge, savedRecipes: saved, shopping: shopping);

  group('RecipeBookScreen', () {
    testWidgets('shows suggestions and every recipe', (tester) async {
      await pump(tester, book());
      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('Suggested for you'), findsOneWidget);
      expect(find.text('All recipes'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Banana bread'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Banana bread'), findsOneWidget);
    });

    testWidgets('searches by ingredient and shows an empty state', (
      tester,
    ) async {
      await pump(tester, book());
      await tester.enterText(
        find.byKey(const ValueKey('recipes-search-field')),
        'flour',
      );
      await tester.pump();
      expect(find.text('Suggested for you'), findsNothing);
      expect(find.text('Pancakes'), findsOneWidget);
      expect(find.text('Shakshuka'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('recipes-search-field')),
        'sushi',
      );
      await tester.pump();
      expect(
        find.text('No recipe found. Try another word or filter.'),
        findsOneWidget,
      );
    });

    testWidgets('the ready to cook filter hides recipes with missing foods', (
      tester,
    ) async {
      await pump(tester, book());
      await tap(tester, 'recipes-filter-readyToCook');
      expect(find.text('Shakshuka'), findsOneWidget);
      expect(find.text('Pancakes'), findsNothing);
      expect(find.text('Lemon chicken & rice'), findsNothing);
    });

    testWidgets('the heart saves and removes a favorite', (tester) async {
      await pump(tester, book());
      await tester.enterText(
        find.byKey(const ValueKey('recipes-search-field')),
        'shakshuka',
      );
      await tester.pump();

      await tap(tester, 'recipe-save-shakshuka');
      expect(saved.isSaved('shakshuka'), isTrue);
      expect(find.text('Shakshuka added to your favorites'), findsOneWidget);

      await tap(tester, 'recipe-save-shakshuka');
      expect(saved.isSaved('shakshuka'), isFalse);
    });

    testWidgets('opens the details and the saved recipes', (tester) async {
      saved.save('pancakes');
      await pump(tester, book());
      await tap(tester, 'recipes-saved-button');
      expect(find.text('Saved recipes'), findsOneWidget);
      expect(find.text('Pancakes'), findsOneWidget);

      await goBack(tester);
      await tester.enterText(
        find.byKey(const ValueKey('recipes-search-field')),
        'shakshuka',
      );
      await tester.pump();
      await tap(tester, 'recipe-tile-shakshuka');
      expect(find.text('Ingredients'), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
    });
  });

  group('RecipeViewScreen', () {
    Widget view(String id) => RecipeViewScreen(
      recipeId: id,
      fridge: fridge,
      savedRecipes: saved,
      shopping: shopping,
    );

    testWidgets('shows fridge foods, missing ingredients and steps', (
      tester,
    ) async {
      await pump(tester, view('lemon-chicken-rice'));
      expect(find.text('Lemon chicken & rice'), findsOneWidget);
      expect(find.textContaining('Chicken breast · '), findsOneWidget);
      expect(find.text('Not in your fridge'), findsOneWidget);
      expect(find.text('1 missing'), findsOneWidget);
    });

    testWidgets('adds the missing ingredients to the shopping list', (
      tester,
    ) async {
      await pump(tester, view('lemon-chicken-rice'));
      await tap(tester, 'recipe-view-add-missing');
      final items = shopping.selectedList!.items.map((i) => i.name);
      expect(items, contains('Rice'));
    });

    testWidgets('"I cooked it" consumes the fridge foods as a recipe', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => view('shakshuka')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tap(tester, 'recipe-view-cooked');
      final cooked = fridge.history.where((e) => e.recipe == 'Shakshuka');
      expect(cooked.length, 2);
      expect(cooked.every((e) => e.type == FridgeEventType.consumed), isTrue);
      expect(find.textContaining('Enjoy your shakshuka'), findsOneWidget);
    });

    testWidgets('the heart in the header toggles the favorite', (tester) async {
      await pump(tester, view('apple-crumble'));
      await tap(tester, 'recipe-view-save');
      expect(saved.isSaved('apple-crumble'), isTrue);
      expect(find.byKey(const ValueKey('recipe-view-cooked')), findsNothing);
    });

    testWidgets('an unknown recipe shows a message', (tester) async {
      await pump(tester, view('nope'));
      expect(find.text('This recipe no longer exists.'), findsOneWidget);
    });
  });

  group('SavedRecipesScreen', () {
    Widget screen() => SavedRecipesScreen(
      fridge: fridge,
      savedRecipes: saved,
      shopping: shopping,
    );

    testWidgets('empty state offers to browse recipes', (tester) async {
      await pump(tester, screen());
      expect(find.text('No saved recipes yet.'), findsOneWidget);
      await tap(tester, 'saved-browse-button');
      expect(find.text('Suggested for you'), findsOneWidget);
    });

    testWidgets('lists favorites newest first and removes with undo', (
      tester,
    ) async {
      saved.restore(
        SavedRecipe(recipeId: 'pancakes', savedAt: DateTime(2026, 10, 1)),
      );
      saved.restore(
        SavedRecipe(recipeId: 'shakshuka', savedAt: DateTime(2026, 10, 2)),
      );
      await pump(tester, screen());

      expect(find.text('2 favorites · 1 ready to cook now'), findsOneWidget);
      final shakshukaY = tester.getTopLeft(find.text('Shakshuka')).dy;
      final pancakesY = tester.getTopLeft(find.text('Pancakes')).dy;
      expect(shakshukaY, lessThan(pancakesY));

      await tap(tester, 'recipe-save-pancakes');
      expect(saved.isSaved('pancakes'), isFalse);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(saved.isSaved('pancakes'), isTrue);
    });

    testWidgets('swipe left removes a favorite', (tester) async {
      saved.save('pancakes');
      await pump(tester, screen());
      await tester.drag(
        find.byKey(const ValueKey('saved-pancakes')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      expect(saved.isSaved('pancakes'), isFalse);
      expect(find.text('Pancakes removed from your favorites'), findsOneWidget);
    });
  });
}

Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
  await tester.pumpAndSettle();
}
