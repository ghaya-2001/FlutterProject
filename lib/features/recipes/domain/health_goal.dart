import '../../fridge/domain/recipes.dart';
import 'nutrition.dart';

/// Health goal chosen in the profile. It decides which recipes are
/// suggested first.
enum HealthGoal {
  none('No goal', 'Recipes are only ranked by your fridge'),
  loseWeight('Lose weight', 'Light recipes first (under 400 kcal)'),
  stayBalanced('Stay balanced', 'Balanced meals first (300–600 kcal, protein)'),
  buildMuscle('Build muscle', 'High-protein recipes first (20 g or more)');

  const HealthGoal(this.label, this.description);

  final String label;
  final String description;

  /// Goal saved under [name], or [none] when unknown.
  static HealthGoal fromName(String? name) {
    for (final goal in values) {
      if (goal.name == name) return goal;
    }
    return HealthGoal.none;
  }

  /// True when [health] matches this goal ([none] matches nothing).
  bool fits(RecipeHealth? health) {
    if (health == null) return false;
    switch (this) {
      case HealthGoal.none:
        return false;
      case HealthGoal.loseWeight:
        return health.kcal < lowCalorieKcal;
      case HealthGoal.stayBalanced:
        return health.kcal >= 300 && health.kcal <= 600 && health.protein >= 12;
      case HealthGoal.buildMuscle:
        return health.protein >= highProteinGrams;
    }
  }

  bool fitsRecipe(Recipe recipe) => fits(healthOf(recipe));
}

/// [items] with the ones fitting [goal] first; the order is kept otherwise.
List<T> rankForGoal<T>(
  Iterable<T> items,
  HealthGoal goal,
  Recipe Function(T item) recipeOf,
) {
  if (goal == HealthGoal.none) return items.toList();
  final fitting = <T>[];
  final others = <T>[];
  for (final item in items) {
    (goal.fitsRecipe(recipeOf(item)) ? fitting : others).add(item);
  }
  return [...fitting, ...others];
}
