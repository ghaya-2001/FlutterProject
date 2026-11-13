import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../../fridge/domain/recipes.dart';
import '../../fridge/presentation/recipes_screen.dart' show defaultCookAmount;
import '../../list/data/shopping_list_repository.dart';
import '../../list/domain/shopping_category.dart';
import '../data/saved_recipes_repository.dart';
import '../domain/extra_recipes.dart';
import '../domain/recipe_search.dart';
import 'widgets/recipe_tile.dart';

/// Details of one recipe: what the fridge already has, what is missing,
/// the steps, and the favorite / shopping list / cooked actions.
class RecipeViewScreen extends StatelessWidget {
  const RecipeViewScreen({
    super.key,
    required this.recipeId,
    this.fridge,
    this.savedRecipes,
    this.shopping,
  });

  final String recipeId;

  /// Default to the app-wide instances; injectable for tests.
  final FridgeRepository? fridge;
  final SavedRecipesRepository? savedRecipes;
  final ShoppingListRepository? shopping;

  FridgeRepository get _fridge => fridge ?? FridgeRepository.instance;
  SavedRecipesRepository get _saved =>
      savedRecipes ?? SavedRecipesRepository.instance;

  void _addMissing(BuildContext context, RecipeMatch match) {
    final list = shopping ?? ShoppingListRepository.instance;
    final target = list.selectedList ?? list.createList('Recipe ingredients');
    for (final ingredient in match.missing) {
      list.addItem(
        target.id,
        name: ingredient.name,
        category:
            list.categoryNamed(ingredient.category) ?? otherShoppingCategory,
        note: 'For ${match.recipe.name}',
      );
    }
    showAppSnackBar(
      context,
      '${match.missing.length} ingredient(s) added to "${target.name}"',
    );
  }

  void _cook(BuildContext context, RecipeMatch match) {
    final amounts = <String, double>{
      for (final food in match.used.values) food.id: defaultCookAmount(food),
    };
    final messenger = ScaffoldMessenger.of(context);
    _fridge.cookRecipe(match.recipe, amounts);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Enjoy your ${match.recipe.name.toLowerCase()}! '
            '${amounts.length} food(s) saved from waste',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = recipeById(recipeId);
    return Scaffold(
      body: SafeArea(
        child: recipe == null
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                child: Column(
                  children: [
                    ScreenHeader(title: 'Recipe'),
                    SizedBox(height: 18),
                    EmptyCard(
                      icon: Icons.no_food_rounded,
                      message: 'This recipe no longer exists.',
                    ),
                  ],
                ),
              )
            : ListenableBuilder(
                listenable: Listenable.merge([_fridge, _saved]),
                builder: (context, _) => _buildBody(context, recipe),
              ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Recipe recipe) {
    final now = _fridge.now;
    final match = matchRecipe(recipe, _fridge.items, now);
    final isSaved = _saved.isSaved(recipe.id);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      children: [
        ScreenHeader(
          title: recipe.name,
          actions: [
            HeaderIconButton(
              key: const ValueKey('recipe-view-save'),
              icon: isSaved
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              tooltip: isSaved ? 'Remove from favorites' : 'Save recipe',
              onPressed: () {
                final saved = _saved.toggle(recipe.id);
                showAppSnackBar(
                  context,
                  saved ? 'Added to your favorites' : 'Removed from favorites',
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF3E0), Color(0xFFE8F5E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(recipe.icon, size: 40, color: recipeOrange),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${recipe.minutes} min · '
                      '${(match.coverage * 100).round()}% in your fridge',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: recipeDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (match.urgentCount > 0)
                          RecipeTag(
                            label: 'Saves ${match.urgentCount} expiring',
                            color: recipeOrange,
                          ),
                        RecipeTag(
                          label: isReadyToCook(match)
                              ? 'Ready to cook'
                              : '${match.missing.length} missing',
                          color: isReadyToCook(match)
                              ? recipeGreen
                              : Colors.black54,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionTitle('Ingredients'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              for (final ingredient in recipe.ingredients)
                _IngredientLine(
                  name: ingredient.name,
                  optional: ingredient.optional,
                  detail: match.used[ingredient] == null
                      ? null
                      : '${match.used[ingredient]!.name} · '
                            '${daysLeftLabel(match.used[ingredient]!, now)}',
                ),
            ],
          ),
        ),
        const SectionTitle('Steps'),
        for (var i = 0; i < recipe.steps.length; i++)
          _StepLine(number: i + 1, text: recipe.steps[i]),
        const SizedBox(height: 18),
        if (match.missing.isNotEmpty)
          OutlinedButton.icon(
            key: const ValueKey('recipe-view-add-missing'),
            onPressed: () => _addMissing(context, match),
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('Add missing to shopping list'),
            style: OutlinedButton.styleFrom(
              foregroundColor: recipeGreen,
              side: const BorderSide(color: recipeGreen),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        if (usesFridge(match)) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            key: const ValueKey('recipe-view-cooked'),
            onPressed: () => _cook(context, match),
            icon: const Icon(Icons.restaurant_rounded),
            label: const Text('I cooked it'),
            style: ElevatedButton.styleFrom(
              backgroundColor: recipeGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Removes the fridge foods used and counts them as saved meals.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ],
    );
  }
}

class _IngredientLine extends StatelessWidget {
  const _IngredientLine({
    required this.name,
    required this.optional,
    required this.detail,
  });

  final String name;
  final bool optional;

  /// Fridge food used and its expiry, or null when it is not in the fridge.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final have = detail != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            have
                ? Icons.check_circle_rounded
                : (optional
                      ? Icons.radio_button_unchecked_rounded
                      : Icons.cancel_rounded),
            color: have
                ? recipeGreen
                : (optional ? Colors.black26 : const Color(0xFFC62828)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  optional ? '$name (optional)' : name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: recipeDark,
                  ),
                ),
                Text(
                  detail ?? (optional ? 'Nice to have' : 'Not in your fridge'),
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: const Color(0xFFC8E6C9),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: recipeGreen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: recipeDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
