import '../../fridge/domain/recipes.dart';

/// Below this many kcal a portion, a recipe is "Low calorie" (and "Light").
const lowCalorieKcal = 400;

/// From this many kcal a portion, a recipe is "Rich".
const richKcal = 500;

/// From this many grams of protein a portion, a recipe is "High protein".
const highProteinGrams = 20;

/// Calories and macros of one portion.
class Nutrition {
  const Nutrition({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final int kcal;

  /// Grams.
  final double protein;
  final double carbs;
  final double fat;

  /// Share of the energy coming from protein, carbs and fat (4, 4 and
  /// 9 kcal a gram), each from 0 to 1. All 0 when there is nothing.
  ({double protein, double carbs, double fat}) get energyShares {
    final p = protein * 4;
    final c = carbs * 4;
    final f = fat * 9;
    final total = p + c + f;
    if (total == 0) {
      return (protein: 0, carbs: 0, fat: 0);
    }
    return (protein: p / total, carbs: c / total, fat: f / total);
  }

  Nutrition operator +(Nutrition other) => Nutrition(
    kcal: kcal + other.kcal,
    protein: protein + other.protein,
    carbs: carbs + other.carbs,
    fat: fat + other.fat,
  );

  static const zero = Nutrition(kcal: 0, protein: 0, carbs: 0, fat: 0);
}

enum CalorieLevel {
  light('Light'),
  balanced('Balanced'),
  rich('Rich');

  const CalorieLevel(this.label);

  final String label;

  static CalorieLevel of(int kcal) {
    if (kcal < lowCalorieKcal) return CalorieLevel.light;
    if (kcal < richKcal) return CalorieLevel.balanced;
    return CalorieLevel.rich;
  }
}

enum HealthTag {
  vegetarian('Vegetarian'),
  highProtein('High protein'),
  lowCalorie('Low calorie'),
  glutenFree('Gluten free');

  const HealthTag(this.label);

  final String label;
}

/// Nutrition and diet facts of one recipe.
class RecipeHealth {
  const RecipeHealth(
    this.kcal,
    this.protein,
    this.carbs,
    this.fat, {
    this.vegetarian = true,
    this.glutenFree = false,
  });

  final int kcal;
  final double protein;
  final double carbs;
  final double fat;
  final bool vegetarian;
  final bool glutenFree;

  Nutrition get nutrition =>
      Nutrition(kcal: kcal, protein: protein, carbs: carbs, fat: fat);

  CalorieLevel get level => CalorieLevel.of(kcal);

  /// "Low calorie" and "High protein" come from the numbers, the others
  /// from the ingredients.
  Set<HealthTag> get tags => {
    if (vegetarian) HealthTag.vegetarian,
    if (protein >= highProteinGrams) HealthTag.highProtein,
    if (kcal < lowCalorieKcal) HealthTag.lowCalorie,
    if (glutenFree) HealthTag.glutenFree,
  };
}

/// Approximate values for one portion (average portions, typical
/// ingredients), keyed by recipe id. Every recipe of `allRecipes` is here.
const recipeHealth = <String, RecipeHealth>{
  // Fridge "Cook now" book (Membre 2)
  'spinach-omelette': RecipeHealth(320, 22, 6, 23, glutenFree: true),
  'shakshuka': RecipeHealth(290, 17, 16, 18, glutenFree: true),
  'lemon-chicken-rice': RecipeHealth(
    520,
    38,
    58,
    14,
    vegetarian: false,
    glutenFree: true,
  ),
  'tomato-pasta': RecipeHealth(480, 16, 78, 12),
  'creamy-spinach-pasta': RecipeHealth(590, 22, 80, 20),
  'chicken-salad': RecipeHealth(
    340,
    32,
    12,
    18,
    vegetarian: false,
    glutenFree: true,
  ),
  'tzatziki': RecipeHealth(150, 9, 10, 8, glutenFree: true),
  'french-toast': RecipeHealth(380, 15, 45, 15),
  'pancakes': RecipeHealth(420, 13, 60, 14),
  'yogurt-lemon-cake': RecipeHealth(360, 9, 52, 13),
  'egg-fried-rice': RecipeHealth(450, 15, 65, 14, glutenFree: true),
  'smoothie': RecipeHealth(220, 6, 42, 3, glutenFree: true),
  // Recipes screen (Membre 5)
  'tomato-soup': RecipeHealth(180, 5, 24, 7, glutenFree: true),
  'spinach-quiche': RecipeHealth(480, 19, 32, 31),
  'chicken-curry': RecipeHealth(
    560,
    40,
    50,
    20,
    vegetarian: false,
    glutenFree: true,
  ),
  'banana-bread': RecipeHealth(330, 7, 52, 11),
  'potato-omelette': RecipeHealth(410, 19, 38, 20, glutenFree: true),
  'veggie-stir-fry': RecipeHealth(380, 11, 58, 11),
  'bruschetta': RecipeHealth(260, 8, 38, 9),
  'greek-salad': RecipeHealth(310, 11, 14, 24, glutenFree: true),
  'lemon-pasta': RecipeHealth(510, 18, 74, 16),
  'chicken-wrap': RecipeHealth(470, 34, 42, 17, vegetarian: false),
  'rice-pudding': RecipeHealth(340, 9, 60, 7, glutenFree: true),
  'yogurt-parfait': RecipeHealth(260, 14, 38, 6),
  'spinach-dal': RecipeHealth(390, 21, 56, 8, glutenFree: true),
  'apple-crumble': RecipeHealth(350, 4, 58, 12),
  'mushroom-risotto': RecipeHealth(540, 15, 78, 18, glutenFree: true),
  'fruit-salad': RecipeHealth(150, 2, 36, 1, glutenFree: true),
};

/// Health facts of [recipe], or null for a recipe without data.
RecipeHealth? healthOf(Recipe recipe) => recipeHealth[recipe.id];

/// Tags of [recipe] (empty without data).
Set<HealthTag> tagsOf(Recipe recipe) => healthOf(recipe)?.tags ?? const {};
