import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/fridge/domain/recipes.dart';
import 'package:foodsaver/features/recipes/domain/extra_recipes.dart';
import 'package:foodsaver/features/recipes/domain/recipe_search.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late FridgeRepository fridge;

  // Seeded fridge: Spinach (2 d), Yogurt (today), Tomatoes (3 d), Milk (5 d),
  // Lemon (7 d), Chicken breast (1 d), Eggs (14 d).
  setUp(() => fridge = FridgeRepository(clock: () => today));

  List<RecipeMatch> all() => matchAllRecipes(fridge.items, today);

  RecipeMatch byId(String id) =>
      all().firstWhere((match) => match.recipe.id == id);

  group('recipe book', () {
    test('has the fridge recipes and the extra ones, with unique ids', () {
      expect(allRecipes.length, recipeBook.length + extraRecipes.length);
      expect(allRecipes.length, greaterThanOrEqualTo(28));
      final ids = allRecipes.map((recipe) => recipe.id).toSet();
      expect(ids.length, allRecipes.length);
    });

    test('recipeById finds a recipe or returns null', () {
      expect(recipeById('shakshuka')?.name, 'Shakshuka');
      expect(recipeById('banana-bread')?.name, 'Banana bread');
      expect(recipeById('nope'), isNull);
    });
  });

  group('matchRecipe', () {
    test('a recipe using fridge foods lists them and what is missing', () {
      final match = byId('lemon-chicken-rice');
      expect(usesFridge(match), isTrue);
      expect(match.used.values.map((f) => f.name), contains('Chicken breast'));
      expect(match.missing.map((i) => i.name), ['Rice']);
      expect(isReadyToCook(match), isFalse);
    });

    test('a recipe using no fridge food has every required ingredient '
        'missing', () {
      final match = byId('apple-crumble');
      expect(usesFridge(match), isFalse);
      expect(match.coverage, 0);
      expect(match.missing.map((i) => i.name), ['Apples', 'Flour']);
    });

    test('ready to cook when every required ingredient is there', () {
      expect(isReadyToCook(byId('shakshuka')), isTrue);
      expect(isReadyToCook(byId('tomato-soup')), isTrue);
    });

    test('recipes saving foods about to expire come first', () {
      final matches = all();
      expect(matches.first.urgentCount, greaterThan(0));
      final firstUnused = matches.indexWhere((m) => !usesFridge(m));
      final lastUsed = matches.lastIndexWhere(usesFridge);
      expect(lastUsed, lessThan(firstUnused));
    });
  });

  group('searchRecipes', () {
    test('finds recipes by name, case and accents ignored', () {
      final results = searchRecipes(all(), query: 'PANCAKE');
      expect(results.map((m) => m.recipe.id), ['pancakes']);
      expect(searchRecipes(all(), query: 'quiché').map((m) => m.recipe.id), [
        'spinach-quiche',
      ]);
    });

    test('finds recipes by ingredient', () {
      final ids = searchRecipes(
        all(),
        query: 'spinach',
      ).map((m) => m.recipe.id).toSet();
      expect(
        ids,
        containsAll([
          'spinach-omelette',
          'creamy-spinach-pasta',
          'spinach-quiche',
          'spinach-dal',
        ]),
      );
      expect(ids, isNot(contains('pancakes')));
    });

    test('a plural or longer word still matches the ingredient keyword', () {
      final ids = searchRecipes(
        all(),
        query: 'tomatoes',
      ).map((m) => m.recipe.id);
      expect(ids, containsAll(['shakshuka', 'tomato-soup', 'bruschetta']));
    });

    test('filters ready to cook, uses my fridge and quick recipes', () {
      final ready = searchRecipes(all(), filter: RecipeFilter.readyToCook);
      expect(ready, isNotEmpty);
      expect(ready.every(isReadyToCook), isTrue);

      final fridgeOnes = searchRecipes(all(), filter: RecipeFilter.usesFridge);
      expect(fridgeOnes.every(usesFridge), isTrue);
      expect(fridgeOnes.length, greaterThan(ready.length));

      final quick = searchRecipes(all(), filter: RecipeFilter.quick);
      expect(
        quick.every((m) => m.recipe.minutes <= quickRecipeMinutes),
        isTrue,
      );
      expect(quick.map((m) => m.recipe.id), contains('smoothie'));
    });

    test('query and filter combine; nothing found gives an empty list', () {
      final results = searchRecipes(
        all(),
        query: 'pasta',
        filter: RecipeFilter.quick,
      );
      expect(results.map((m) => m.recipe.id), ['lemon-pasta']);
      expect(searchRecipes(all(), query: 'sushi'), isEmpty);
    });

    test('normalizeSearch removes case, accents and spaces', () {
      expect(normalizeSearch('  Crème Brûlée '), 'creme brulee');
    });
  });
}
