import '../../fridge/domain/food_item.dart';
import '../../fridge/domain/recipes.dart';
import 'extra_recipes.dart';
import 'nutrition.dart';

/// Filters of the Recipes screen.
enum RecipeFilter {
  all('All'),
  readyToCook('Ready to cook'),
  usesFridge('Uses my fridge'),
  quick('Quick'),
  vegetarian('Vegetarian'),
  highProtein('High protein'),
  lowCalorie('Low calorie'),
  glutenFree('Gluten free');

  const RecipeFilter(this.label);

  final String label;
}

/// Recipes ready in this many minutes or less are "quick".
const quickRecipeMinutes = 15;

/// How well [recipe] fits the fridge. Unlike [suggestRecipes], it always
/// returns a match: a recipe using none of the fridge foods has every
/// required ingredient missing.
RecipeMatch matchRecipe(Recipe recipe, List<FoodItem> items, DateTime now) {
  final matches = suggestRecipes(items, now, recipes: [recipe]);
  if (matches.isNotEmpty) {
    return matches.first;
  }
  return RecipeMatch(
    recipe: recipe,
    used: const {},
    missing: recipe.requiredIngredients,
    urgentCount: 0,
  );
}

/// Every recipe matched against the fridge, best first: the ones saving the
/// most foods about to expire, then the most complete, then the quickest.
List<RecipeMatch> matchAllRecipes(
  List<FoodItem> items,
  DateTime now, {
  List<Recipe> recipes = allRecipes,
}) {
  final matches = [
    for (final recipe in recipes) matchRecipe(recipe, items, now),
  ];
  matches.sort(compareRecipeMatches);
  return matches;
}

int compareRecipeMatches(RecipeMatch a, RecipeMatch b) {
  final byUrgent = b.urgentCount.compareTo(a.urgentCount);
  if (byUrgent != 0) return byUrgent;
  final byCoverage = b.coverage.compareTo(a.coverage);
  if (byCoverage != 0) return byCoverage;
  final byMinutes = a.recipe.minutes.compareTo(b.recipe.minutes);
  if (byMinutes != 0) return byMinutes;
  return a.recipe.name.compareTo(b.recipe.name);
}

/// True when the match uses at least one food of the fridge.
bool usesFridge(RecipeMatch match) => match.used.isNotEmpty;

/// True when every required ingredient is in the fridge.
bool isReadyToCook(RecipeMatch match) => usesFridge(match) && match.canCook;

/// Keeps the matches whose recipe name or ingredients contain [query]
/// (case and accents ignored) and that pass [filter]. The order is kept.
List<RecipeMatch> searchRecipes(
  List<RecipeMatch> matches, {
  String query = '',
  RecipeFilter filter = RecipeFilter.all,
}) {
  final needle = normalizeSearch(query);
  return matches.where((match) {
    if (!_passes(match, filter)) {
      return false;
    }
    return needle.isEmpty || _recipeContains(match.recipe, needle);
  }).toList();
}

bool _passes(RecipeMatch match, RecipeFilter filter) {
  switch (filter) {
    case RecipeFilter.all:
      return true;
    case RecipeFilter.readyToCook:
      return isReadyToCook(match);
    case RecipeFilter.usesFridge:
      return usesFridge(match);
    case RecipeFilter.quick:
      return match.recipe.minutes <= quickRecipeMinutes;
    case RecipeFilter.vegetarian:
      return tagsOf(match.recipe).contains(HealthTag.vegetarian);
    case RecipeFilter.highProtein:
      return tagsOf(match.recipe).contains(HealthTag.highProtein);
    case RecipeFilter.lowCalorie:
      return tagsOf(match.recipe).contains(HealthTag.lowCalorie);
    case RecipeFilter.glutenFree:
      return tagsOf(match.recipe).contains(HealthTag.glutenFree);
  }
}

bool _recipeContains(Recipe recipe, String needle) {
  if (normalizeSearch(recipe.name).contains(needle)) {
    return true;
  }
  for (final ingredient in recipe.ingredients) {
    if (normalizeSearch(ingredient.name).contains(needle)) {
      return true;
    }
    // "tomates" finds tomatoes, "oeuf" does not, but "egg" does.
    if (ingredient.keywords.any((keyword) => needle.startsWith(keyword))) {
      return true;
    }
  }
  return false;
}

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', //
  'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', //
  'û': 'u', 'ü': 'u', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
};

/// Lower case, without accents and surrounding spaces.
String normalizeSearch(String text) {
  final buffer = StringBuffer();
  for (final char in text.trim().toLowerCase().split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}
