import 'package:flutter/material.dart';

import 'food_item.dart';

/// One ingredient of a [Recipe].
///
/// A fridge food matches when one of the words of its name starts with one
/// of the [keywords] ("Cherry tomatoes" matches "tomato").
class RecipeIngredient {
  const RecipeIngredient(
    this.name, {
    required this.keywords,
    required this.category,
    this.optional = false,
  });

  final String name;
  final List<String> keywords;

  /// Category used when the ingredient is added to the shopping list.
  final String category;

  /// Optional ingredients improve the recipe but are never "missing".
  final bool optional;

  bool matches(FoodItem item) {
    final words = item.name.toLowerCase().split(RegExp(r'[^a-zà-ÿ]+'));
    return words.any(
      (word) => word.isNotEmpty && keywords.any(word.startsWith),
    );
  }
}

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.icon,
    required this.minutes,
    required this.ingredients,
    required this.steps,
  });

  final String id;
  final String name;
  final IconData icon;
  final int minutes;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;

  List<RecipeIngredient> get requiredIngredients =>
      ingredients.where((ingredient) => !ingredient.optional).toList();
}

/// How well a recipe fits what is in the fridge right now.
class RecipeMatch {
  const RecipeMatch({
    required this.recipe,
    required this.used,
    required this.missing,
    required this.urgentCount,
  });

  final Recipe recipe;

  /// Fridge food chosen for each available ingredient (soonest expiry first).
  final Map<RecipeIngredient, FoodItem> used;

  /// Required ingredients that are not in the fridge.
  final List<RecipeIngredient> missing;

  /// Used foods that must be eaten first (expiring within 3 days).
  final int urgentCount;

  bool get canCook => missing.isEmpty;

  /// Share of the required ingredients found in the fridge, from 0 to 1.
  double get coverage {
    final required = recipe.requiredIngredients.length;
    return required == 0 ? 1 : (required - missing.length) / required;
  }
}

/// Recipes that can use the fridge foods, best first: the ones that save the
/// most foods about to expire, then the most complete ones.
List<RecipeMatch> suggestRecipes(
  List<FoodItem> items,
  DateTime now, {
  List<Recipe> recipes = recipeBook,
}) {
  final usable = items.where((item) => !item.isExpired(now)).toList()
    ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

  final matches = <RecipeMatch>[];
  for (final recipe in recipes) {
    final used = <RecipeIngredient, FoodItem>{};
    final missing = <RecipeIngredient>[];
    for (final ingredient in recipe.ingredients) {
      FoodItem? food;
      for (final item in usable) {
        if (ingredient.matches(item) && !used.containsValue(item)) {
          food = item;
          break;
        }
      }
      if (food != null) {
        used[ingredient] = food;
      } else if (!ingredient.optional) {
        missing.add(ingredient);
      }
    }
    final usesRequired = recipe.requiredIngredients.any(used.containsKey);
    if (!usesRequired) {
      continue;
    }
    matches.add(
      RecipeMatch(
        recipe: recipe,
        used: used,
        missing: missing,
        urgentCount: used.values.where((item) => item.isPriority(now)).length,
      ),
    );
  }

  matches.sort((a, b) {
    final byUrgent = b.urgentCount.compareTo(a.urgentCount);
    if (byUrgent != 0) return byUrgent;
    final byCoverage = b.coverage.compareTo(a.coverage);
    if (byCoverage != 0) return byCoverage;
    return a.recipe.minutes.compareTo(b.recipe.minutes);
  });
  return matches;
}

// -----------------------------------------------------------------------------
// Recipe book: simple everyday recipes made of common fridge foods.
// -----------------------------------------------------------------------------

const _eggs = RecipeIngredient('Eggs', keywords: ['egg'], category: 'Dairy');
const _milk = RecipeIngredient('Milk', keywords: ['milk'], category: 'Dairy');
const _cheese = RecipeIngredient(
  'Cheese',
  keywords: ['cheese', 'cheddar', 'mozzarella', 'parmesan', 'feta'],
  category: 'Dairy',
  optional: true,
);
const _yogurt = RecipeIngredient(
  'Yogurt',
  keywords: ['yogurt', 'yoghurt'],
  category: 'Dairy',
);
const _tomatoes = RecipeIngredient(
  'Tomatoes',
  keywords: ['tomato'],
  category: 'Vegetables',
);
const _spinach = RecipeIngredient(
  'Spinach',
  keywords: ['spinach'],
  category: 'Vegetables',
);
const _onion = RecipeIngredient(
  'Onion',
  keywords: ['onion', 'shallot'],
  category: 'Vegetables',
  optional: true,
);
const _garlic = RecipeIngredient(
  'Garlic',
  keywords: ['garlic'],
  category: 'Vegetables',
  optional: true,
);
const _lemon = RecipeIngredient(
  'Lemon',
  keywords: ['lemon', 'lime'],
  category: 'Fruits',
);
const _chicken = RecipeIngredient(
  'Chicken',
  keywords: ['chicken'],
  category: 'Meat & Fish',
);
const _pasta = RecipeIngredient(
  'Pasta',
  keywords: ['pasta', 'spaghetti', 'penne', 'noodle'],
  category: 'Pantry',
);
const _rice = RecipeIngredient('Rice', keywords: ['rice'], category: 'Pantry');
const _bread = RecipeIngredient(
  'Bread',
  keywords: ['bread', 'baguette', 'toast'],
  category: 'Bakery',
);
const _flour = RecipeIngredient(
  'Flour',
  keywords: ['flour'],
  category: 'Pantry',
);

const recipeBook = <Recipe>[
  Recipe(
    id: 'spinach-omelette',
    name: 'Spinach omelette',
    icon: Icons.egg_alt_rounded,
    minutes: 10,
    ingredients: [_eggs, _spinach, _milk, _cheese],
    steps: [
      'Beat the eggs with a splash of milk, salt and pepper.',
      'Wilt the spinach in a hot pan with a little oil.',
      'Pour the eggs over, add cheese and fold when just set.',
    ],
  ),
  Recipe(
    id: 'shakshuka',
    name: 'Shakshuka',
    icon: Icons.local_fire_department_rounded,
    minutes: 25,
    ingredients: [_tomatoes, _eggs, _onion, _garlic],
    steps: [
      'Soften the onion and garlic in olive oil.',
      'Add the chopped tomatoes and simmer 10 minutes.',
      'Make small wells, crack the eggs in and cover until set.',
    ],
  ),
  Recipe(
    id: 'lemon-chicken-rice',
    name: 'Lemon chicken & rice',
    icon: Icons.set_meal_rounded,
    minutes: 30,
    ingredients: [_chicken, _lemon, _rice, _garlic],
    steps: [
      'Marinate the chicken with lemon juice, garlic and salt.',
      'Cook the rice.',
      'Pan-fry the chicken until golden and serve on the rice.',
    ],
  ),
  Recipe(
    id: 'tomato-pasta',
    name: 'Fresh tomato pasta',
    icon: Icons.ramen_dining_rounded,
    minutes: 20,
    ingredients: [_pasta, _tomatoes, _garlic, _cheese],
    steps: [
      'Cook the pasta in salted water.',
      'Cook the tomatoes and garlic in olive oil until saucy.',
      'Mix with the pasta and top with cheese.',
    ],
  ),
  Recipe(
    id: 'creamy-spinach-pasta',
    name: 'Creamy spinach pasta',
    icon: Icons.dinner_dining_rounded,
    minutes: 20,
    ingredients: [_pasta, _spinach, _milk, _cheese, _garlic],
    steps: [
      'Cook the pasta.',
      'Wilt the spinach with garlic, add the milk and reduce.',
      'Stir in the cheese and the pasta.',
    ],
  ),
  Recipe(
    id: 'chicken-salad',
    name: 'Chicken & tomato salad',
    icon: Icons.eco_rounded,
    minutes: 15,
    ingredients: [
      _chicken,
      _tomatoes,
      _lemon,
      RecipeIngredient(
        'Salad',
        keywords: ['lettuce', 'salad', 'rocket', 'spinach'],
        category: 'Vegetables',
        optional: true,
      ),
    ],
    steps: [
      'Grill the chicken and slice it.',
      'Cut the tomatoes and mix with the leaves.',
      'Dress with lemon juice, olive oil, salt and pepper.',
    ],
  ),
  Recipe(
    id: 'tzatziki',
    name: 'Lemon yogurt dip',
    icon: Icons.soup_kitchen_rounded,
    minutes: 5,
    ingredients: [
      _yogurt,
      _lemon,
      _garlic,
      RecipeIngredient(
        'Cucumber',
        keywords: ['cucumber'],
        category: 'Vegetables',
        optional: true,
      ),
    ],
    steps: [
      'Grate the cucumber and squeeze out the water.',
      'Mix with the yogurt, lemon juice and garlic.',
      'Serve cold with bread or vegetables.',
    ],
  ),
  Recipe(
    id: 'french-toast',
    name: 'French toast',
    icon: Icons.breakfast_dining_rounded,
    minutes: 10,
    ingredients: [_bread, _eggs, _milk],
    steps: [
      'Whisk the eggs and milk (add cinnamon if you like).',
      'Soak the bread slices — perfect for stale bread.',
      'Cook in a buttered pan until golden on both sides.',
    ],
  ),
  Recipe(
    id: 'pancakes',
    name: 'Pancakes',
    icon: Icons.cookie_rounded,
    minutes: 20,
    ingredients: [_flour, _eggs, _milk],
    steps: [
      'Whisk the flour, eggs and milk into a smooth batter.',
      'Rest 5 minutes.',
      'Cook small ladles in a hot pan, flip when bubbles appear.',
    ],
  ),
  Recipe(
    id: 'yogurt-lemon-cake',
    name: 'Yogurt lemon cake',
    icon: Icons.cake_rounded,
    minutes: 45,
    ingredients: [_yogurt, _eggs, _lemon, _flour],
    steps: [
      'Mix the yogurt, eggs, sugar and lemon zest.',
      'Fold in the flour with a little baking powder.',
      'Bake 35 minutes at 180 °C.',
    ],
  ),
  Recipe(
    id: 'egg-fried-rice',
    name: 'Leftover fried rice',
    icon: Icons.rice_bowl_rounded,
    minutes: 15,
    ingredients: [
      _rice,
      _eggs,
      RecipeIngredient(
        'Vegetables',
        keywords: ['carrot', 'pea', 'pepper', 'spinach', 'onion', 'leftover'],
        category: 'Vegetables',
        optional: true,
      ),
    ],
    steps: [
      'Use cold cooked rice (yesterday\'s is best).',
      'Scramble the eggs in a hot pan, then add the vegetables.',
      'Add the rice and soy sauce, stir-fry 3 minutes.',
    ],
  ),
  Recipe(
    id: 'smoothie',
    name: 'Fruit smoothie',
    icon: Icons.local_drink_rounded,
    minutes: 5,
    ingredients: [
      RecipeIngredient(
        'Fruit',
        keywords: [
          'banana',
          'strawberr',
          'berr',
          'apple',
          'mango',
          'peach',
          'pear',
        ],
        category: 'Fruits',
      ),
      _yogurt,
      RecipeIngredient(
        'Milk',
        keywords: ['milk'],
        category: 'Dairy',
        optional: true,
      ),
    ],
    steps: [
      'Cut the fruit — very ripe fruit gives the sweetest smoothie.',
      'Blend with the yogurt and a splash of milk.',
    ],
  ),
];
