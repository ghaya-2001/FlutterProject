import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/recipes/domain/extra_recipes.dart';
import 'package:foodsaver/features/recipes/domain/health_goal.dart';
import 'package:foodsaver/features/recipes/domain/nutrition.dart';
import 'package:foodsaver/features/recipes/domain/recipe_search.dart';

void main() {
  test('every recipe has nutrition data', () {
    for (final recipe in allRecipes) {
      expect(healthOf(recipe), isNotNull, reason: recipe.id);
    }
    expect(recipeHealth.length, allRecipes.length);
  });

  group('RecipeHealth', () {
    test('tags come from the numbers and the ingredients', () {
      expect(recipeHealth['chicken-curry']!.tags, {
        HealthTag.highProtein,
        HealthTag.glutenFree,
      });
      expect(recipeHealth['fruit-salad']!.tags, {
        HealthTag.vegetarian,
        HealthTag.lowCalorie,
        HealthTag.glutenFree,
      });
      expect(recipeHealth['lemon-pasta']!.tags, {HealthTag.vegetarian});
    });

    test('calorie levels', () {
      expect(CalorieLevel.of(399), CalorieLevel.light);
      expect(CalorieLevel.of(400), CalorieLevel.balanced);
      expect(CalorieLevel.of(500), CalorieLevel.rich);
    });

    test('energy shares use 4, 4 and 9 kcal a gram', () {
      const nutrition = Nutrition(kcal: 170, protein: 10, carbs: 20, fat: 10);
      final shares = nutrition.energyShares;
      expect(shares.protein, closeTo(40 / 210, 1e-9));
      expect(shares.carbs, closeTo(80 / 210, 1e-9));
      expect(shares.fat, closeTo(90 / 210, 1e-9));
      expect(Nutrition.zero.energyShares.protein, 0);
    });

    test('nutrition values add up', () {
      final sum =
          recipeHealth['smoothie']!.nutrition +
          recipeHealth['tzatziki']!.nutrition;
      expect(sum.kcal, 370);
      expect(sum.protein, 15);
    });
  });

  group('health filters', () {
    final matches = matchAllRecipes([], DateTime(2026, 11, 16));

    List<String> idsFor(RecipeFilter filter) => [
      for (final match in searchRecipes(matches, filter: filter))
        match.recipe.id,
    ];

    test('vegetarian hides chicken recipes', () {
      final ids = idsFor(RecipeFilter.vegetarian);
      expect(ids, isNot(contains('chicken-curry')));
      expect(ids, contains('spinach-dal'));
    });

    test('high protein, low calorie and gluten free', () {
      expect(idsFor(RecipeFilter.highProtein), contains('chicken-wrap'));
      expect(idsFor(RecipeFilter.highProtein), isNot(contains('pancakes')));
      expect(idsFor(RecipeFilter.lowCalorie), contains('tomato-soup'));
      expect(idsFor(RecipeFilter.lowCalorie), isNot(contains('lemon-pasta')));
      expect(idsFor(RecipeFilter.glutenFree), contains('mushroom-risotto'));
      expect(idsFor(RecipeFilter.glutenFree), isNot(contains('bruschetta')));
    });
  });

  group('HealthGoal', () {
    test('which recipes fit each goal', () {
      final soup = recipeById('tomato-soup')!; // 180 kcal, 5 g protein
      final curry = recipeById('chicken-curry')!; // 560 kcal, 40 g protein
      final dal = recipeById('spinach-dal')!; // 390 kcal, 21 g protein

      expect(HealthGoal.none.fitsRecipe(soup), isFalse);
      expect(HealthGoal.loseWeight.fitsRecipe(soup), isTrue);
      expect(HealthGoal.loseWeight.fitsRecipe(curry), isFalse);
      expect(HealthGoal.buildMuscle.fitsRecipe(curry), isTrue);
      expect(HealthGoal.buildMuscle.fitsRecipe(soup), isFalse);
      expect(HealthGoal.stayBalanced.fitsRecipe(dal), isTrue);
      expect(HealthGoal.stayBalanced.fitsRecipe(soup), isFalse);
    });

    test('fromName falls back to none', () {
      expect(HealthGoal.fromName('buildMuscle'), HealthGoal.buildMuscle);
      expect(HealthGoal.fromName('unknown'), HealthGoal.none);
      expect(HealthGoal.fromName(null), HealthGoal.none);
    });

    test('rankForGoal puts the fitting recipes first, order kept', () {
      final recipes = [
        recipeById('pancakes')!,
        recipeById('chicken-curry')!,
        recipeById('tomato-soup')!,
        recipeById('chicken-wrap')!,
      ];
      List<String> ids(HealthGoal goal) => [
        for (final recipe in rankForGoal(recipes, goal, (r) => r)) recipe.id,
      ];
      expect(ids(HealthGoal.buildMuscle), [
        'chicken-curry',
        'chicken-wrap',
        'pancakes',
        'tomato-soup',
      ]);
      expect(ids(HealthGoal.none), [
        'pancakes',
        'chicken-curry',
        'tomato-soup',
        'chicken-wrap',
      ]);
    });
  });
}
