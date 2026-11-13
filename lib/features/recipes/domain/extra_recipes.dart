import 'package:flutter/material.dart';

import '../../fridge/domain/recipes.dart';

/// Every recipe of the app: the fridge "Cook now" book (Membre 2) plus the
/// extra recipes of the Recipes screen (Membre 5).
const allRecipes = <Recipe>[...recipeBook, ...extraRecipes];

/// Recipe with this id, or null when it no longer exists (e.g. a favorite
/// saved by an older version of the app).
Recipe? recipeById(String id) {
  for (final recipe in allRecipes) {
    if (recipe.id == id) {
      return recipe;
    }
  }
  return null;
}

// -----------------------------------------------------------------------------
// Ingredients
// -----------------------------------------------------------------------------

const _eggs = RecipeIngredient('Eggs', keywords: ['egg'], category: 'Dairy');
const _milk = RecipeIngredient('Milk', keywords: ['milk'], category: 'Dairy');
const _yogurt = RecipeIngredient(
  'Yogurt',
  keywords: ['yogurt', 'yoghurt'],
  category: 'Dairy',
);
const _cheese = RecipeIngredient(
  'Cheese',
  keywords: ['cheese', 'cheddar', 'mozzarella', 'parmesan', 'feta'],
  category: 'Dairy',
  optional: true,
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
const _potatoes = RecipeIngredient(
  'Potatoes',
  keywords: ['potato'],
  category: 'Vegetables',
);
const _cucumber = RecipeIngredient(
  'Cucumber',
  keywords: ['cucumber'],
  category: 'Vegetables',
);
const _mushrooms = RecipeIngredient(
  'Mushrooms',
  keywords: ['mushroom', 'champignon'],
  category: 'Vegetables',
);
const _banana = RecipeIngredient(
  'Bananas',
  keywords: ['banana'],
  category: 'Fruits',
);
const _apple = RecipeIngredient(
  'Apples',
  keywords: ['apple'],
  category: 'Fruits',
);
const _lentils = RecipeIngredient(
  'Lentils',
  keywords: ['lentil'],
  category: 'Pantry',
);
const _fruit = RecipeIngredient(
  'Fruit',
  keywords: [
    'banana',
    'strawberr',
    'berr',
    'apple',
    'mango',
    'peach',
    'pear',
    'orange',
    'kiwi',
    'grape',
  ],
  category: 'Fruits',
);
const _vegetables = RecipeIngredient(
  'Vegetables',
  keywords: [
    'carrot',
    'pepper',
    'broccoli',
    'zucchini',
    'courgette',
    'cabbage',
    'mushroom',
    'pea',
    'bean',
  ],
  category: 'Vegetables',
);

// -----------------------------------------------------------------------------
// Recipes
// -----------------------------------------------------------------------------

const extraRecipes = <Recipe>[
  Recipe(
    id: 'tomato-soup',
    name: 'Roasted tomato soup',
    icon: Icons.soup_kitchen_rounded,
    minutes: 30,
    ingredients: [_tomatoes, _onion, _garlic],
    steps: [
      'Roast the tomatoes, onion and garlic 20 minutes at 200 °C.',
      'Blend with a glass of water, salt and pepper.',
      'Warm up and serve with bread — soft tomatoes are perfect here.',
    ],
  ),
  Recipe(
    id: 'spinach-quiche',
    name: 'Spinach & cheese quiche',
    icon: Icons.pie_chart_rounded,
    minutes: 50,
    ingredients: [_eggs, _spinach, _milk, _flour, _cheese],
    steps: [
      'Make a quick dough with flour, butter and a pinch of salt.',
      'Wilt the spinach, then whisk the eggs with the milk.',
      'Fill the dough with spinach, egg mix and cheese.',
      'Bake 35 minutes at 180 °C.',
    ],
  ),
  Recipe(
    id: 'chicken-curry',
    name: 'Yogurt chicken curry',
    icon: Icons.local_dining_rounded,
    minutes: 35,
    ingredients: [
      _chicken,
      _yogurt,
      _onion,
      RecipeIngredient(
        'Rice',
        keywords: ['rice'],
        category: 'Pantry',
        optional: true,
      ),
    ],
    steps: [
      'Marinate the chicken in yogurt with curry spices.',
      'Brown the onion, add the chicken and cook 20 minutes.',
      'Serve with rice or bread.',
    ],
  ),
  Recipe(
    id: 'banana-bread',
    name: 'Banana bread',
    icon: Icons.bakery_dining_rounded,
    minutes: 60,
    ingredients: [_banana, _eggs, _flour],
    steps: [
      'Mash the very ripe bananas — the browner the better.',
      'Mix with the eggs, sugar and melted butter, then the flour.',
      'Bake 50 minutes at 175 °C.',
    ],
  ),
  Recipe(
    id: 'potato-omelette',
    name: 'Potato omelette',
    icon: Icons.egg_rounded,
    minutes: 30,
    ingredients: [_potatoes, _eggs, _onion],
    steps: [
      'Slice the potatoes thinly and cook them slowly in oil with the onion.',
      'Beat the eggs, add the potatoes and season.',
      'Cook on low heat, flip with a plate and finish the other side.',
    ],
  ),
  Recipe(
    id: 'veggie-stir-fry',
    name: 'Fridge-clearing stir-fry',
    icon: Icons.whatshot_rounded,
    minutes: 15,
    ingredients: [
      _vegetables,
      _garlic,
      RecipeIngredient(
        'Rice or noodles',
        keywords: ['rice', 'noodle'],
        category: 'Pantry',
        optional: true,
      ),
    ],
    steps: [
      'Cut every vegetable that needs using into thin strips.',
      'Stir-fry on high heat with garlic and a little oil.',
      'Add soy sauce and serve on rice or noodles.',
    ],
  ),
  Recipe(
    id: 'bruschetta',
    name: 'Tomato bruschetta',
    icon: Icons.breakfast_dining_rounded,
    minutes: 10,
    ingredients: [_bread, _tomatoes, _garlic],
    steps: [
      'Toast slices of bread (yesterday\'s bread works best).',
      'Rub with garlic and top with diced tomatoes.',
      'Finish with olive oil, salt and basil.',
    ],
  ),
  Recipe(
    id: 'greek-salad',
    name: 'Greek salad',
    icon: Icons.eco_rounded,
    minutes: 10,
    ingredients: [_tomatoes, _cucumber, _cheese, _onion],
    steps: [
      'Cut the tomatoes and cucumber into chunks.',
      'Add sliced onion and feta.',
      'Dress with olive oil, oregano and salt.',
    ],
  ),
  Recipe(
    id: 'lemon-pasta',
    name: 'Lemon pasta',
    icon: Icons.ramen_dining_rounded,
    minutes: 15,
    ingredients: [_pasta, _lemon, _cheese],
    steps: [
      'Cook the pasta and keep a cup of the cooking water.',
      'Mix with lemon zest and juice, olive oil and cheese.',
      'Loosen with a little pasta water and serve.',
    ],
  ),
  Recipe(
    id: 'chicken-wrap',
    name: 'Chicken wraps',
    icon: Icons.lunch_dining_rounded,
    minutes: 15,
    ingredients: [
      _chicken,
      RecipeIngredient(
        'Wraps or bread',
        keywords: ['wrap', 'tortilla', 'pita', 'bread'],
        category: 'Bakery',
      ),
      RecipeIngredient(
        'Tomatoes',
        keywords: ['tomato'],
        category: 'Vegetables',
        optional: true,
      ),
      RecipeIngredient(
        'Yogurt',
        keywords: ['yogurt', 'yoghurt'],
        category: 'Dairy',
        optional: true,
      ),
    ],
    steps: [
      'Pan-fry thin strips of chicken with spices.',
      'Spread yogurt on the wraps and add tomatoes.',
      'Add the chicken, roll and cut in half.',
    ],
  ),
  Recipe(
    id: 'rice-pudding',
    name: 'Rice pudding',
    icon: Icons.icecream_rounded,
    minutes: 40,
    ingredients: [_rice, _milk],
    steps: [
      'Simmer the rice in the milk with sugar and vanilla.',
      'Stir often for 30 minutes until creamy.',
      'Serve warm or cold, with cinnamon.',
    ],
  ),
  Recipe(
    id: 'yogurt-parfait',
    name: 'Yogurt fruit parfait',
    icon: Icons.local_cafe_rounded,
    minutes: 5,
    ingredients: [
      _yogurt,
      _fruit,
      RecipeIngredient(
        'Oats',
        keywords: ['oat', 'granola', 'muesli'],
        category: 'Pantry',
        optional: true,
      ),
    ],
    steps: [
      'Cut the fruit into small pieces.',
      'Layer yogurt, fruit and oats in a glass.',
    ],
  ),
  Recipe(
    id: 'spinach-dal',
    name: 'Lentil & spinach dal',
    icon: Icons.rice_bowl_rounded,
    minutes: 35,
    ingredients: [_lentils, _spinach, _onion, _garlic],
    steps: [
      'Soften the onion and garlic with curry spices.',
      'Add the lentils and water, simmer 25 minutes.',
      'Stir in the spinach at the end until wilted.',
    ],
  ),
  Recipe(
    id: 'apple-crumble',
    name: 'Apple crumble',
    icon: Icons.cake_rounded,
    minutes: 45,
    ingredients: [_apple, _flour],
    steps: [
      'Cut the apples (soft ones are fine) and put them in a dish.',
      'Rub flour, sugar and butter into crumbs.',
      'Cover the apples and bake 30 minutes at 180 °C.',
    ],
  ),
  Recipe(
    id: 'mushroom-risotto',
    name: 'Mushroom risotto',
    icon: Icons.dinner_dining_rounded,
    minutes: 35,
    ingredients: [_rice, _mushrooms, _onion, _cheese],
    steps: [
      'Soften the onion, add the rice and toast 1 minute.',
      'Add hot stock little by little, stirring, for 18 minutes.',
      'Stir in the fried mushrooms and the cheese.',
    ],
  ),
  Recipe(
    id: 'fruit-salad',
    name: 'Fruit salad',
    icon: Icons.apple_rounded,
    minutes: 10,
    ingredients: [
      _fruit,
      RecipeIngredient(
        'Lemon',
        keywords: ['lemon', 'lime'],
        category: 'Fruits',
        optional: true,
      ),
    ],
    steps: [
      'Cut every fruit that is getting soft into pieces.',
      'Add a squeeze of lemon so it stays fresh.',
      'Chill 10 minutes and serve.',
    ],
  ),
];
