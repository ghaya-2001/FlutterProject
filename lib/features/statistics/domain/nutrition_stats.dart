import '../../fridge/domain/fridge_event.dart';
import '../../fridge/domain/recipes.dart';
import '../../recipes/domain/extra_recipes.dart';
import '../../recipes/domain/health_goal.dart';
import '../../recipes/domain/nutrition.dart';
import 'impact.dart';

/// One recipe cooked with "I cooked it" (one portion).
class CookedMeal {
  const CookedMeal({required this.recipe, required this.at});

  final Recipe recipe;
  final DateTime at;

  RecipeHealth? get health => healthOf(recipe);
}

/// Foods of one cooked recipe are recorded together: events of the same
/// recipe less than this apart are one meal.
const _sameCookingGap = Duration(minutes: 1);

/// Every cooked meal of [history], newest first. Events of a recipe that
/// no longer exists are skipped.
List<CookedMeal> cookedMeals(List<FridgeEvent> history) {
  final events = [
    for (final event in history)
      if (event.recipe != null && !event.isWaste) event,
  ]..sort((a, b) => b.at.compareTo(a.at));

  final meals = <CookedMeal>[];
  FridgeEvent? previous;
  for (final event in events) {
    final sameMeal =
        previous != null &&
        previous.recipe == event.recipe &&
        previous.at.difference(event.at).abs() < _sameCookingGap;
    previous = event;
    if (sameMeal) continue;
    final recipe = recipeByName(event.recipe!);
    if (recipe != null) {
      meals.add(CookedMeal(recipe: recipe, at: event.at));
    }
  }
  return meals;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Calories and macros of the meals cooked over a period.
///
/// Never stored: always computed from the fridge history.
class NutritionStats {
  NutritionStats(
    List<CookedMeal> meals,
    DateTime now, {
    this.period = StatsPeriod.allTime,
  }) {
    final days = period.days;
    final from = days == null
        ? null
        : _dateOnly(now).subtract(Duration(days: days - 1));
    this.meals = [
      for (final meal in meals)
        if (from == null || !_dateOnly(meal.at).isBefore(from)) meal,
    ];
  }

  factory NutritionStats.from({
    required List<FridgeEvent> history,
    required DateTime now,
    StatsPeriod period = StatsPeriod.allTime,
  }) => NutritionStats(cookedMeals(history), now, period: period);

  final StatsPeriod period;

  /// Meals of [period], newest first.
  late final List<CookedMeal> meals;

  bool get isEmpty => meals.isEmpty;

  int get mealCount => meals.length;

  /// Sum of the meals with nutrition data.
  Nutrition get total => meals.fold(
    Nutrition.zero,
    (sum, meal) => meal.health == null ? sum : sum + meal.health!.nutrition,
  );

  /// Average kcal a meal, 0 without meals.
  int get averageKcal => isEmpty ? 0 : (total.kcal / mealCount).round();

  /// Meals with [tag].
  int countTag(HealthTag tag) =>
      meals.where((meal) => meal.health?.tags.contains(tag) ?? false).length;

  /// Meals matching [goal].
  int countGoal(HealthGoal goal) =>
      meals.where((meal) => goal.fits(meal.health)).length;
}
