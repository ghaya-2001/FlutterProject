import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../list/data/shopping_list_repository.dart';
import '../data/saved_recipes_repository.dart';
import '../domain/extra_recipes.dart';
import '../domain/recipe_search.dart';
import 'recipe_book_screen.dart';
import 'recipe_view_screen.dart';
import 'widgets/recipe_tile.dart';

/// "Saved Recipes" screen (Membre 5): the user's favorites, newest first.
class SavedRecipesScreen extends StatelessWidget {
  const SavedRecipesScreen({
    super.key,
    this.fridge,
    this.savedRecipes,
    this.shopping,
  });

  /// Default to the app-wide instances; injectable for tests.
  final FridgeRepository? fridge;
  final SavedRecipesRepository? savedRecipes;
  final ShoppingListRepository? shopping;

  FridgeRepository get _fridge => fridge ?? FridgeRepository.instance;
  SavedRecipesRepository get _saved =>
      savedRecipes ?? SavedRecipesRepository.instance;

  void _remove(BuildContext context, String recipeId, String name) {
    final removed = _saved.remove(recipeId);
    if (removed == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$name removed from your favorites'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _saved.restore(removed),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_fridge, _saved]),
          builder: (context, _) {
            final now = _fridge.now;
            final matches = [
              for (final saved in _saved.saved)
                if (recipeById(saved.recipeId) case final recipe?)
                  matchRecipe(recipe, _fridge.items, now),
            ];
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              children: [
                const ScreenHeader(title: 'Saved recipes'),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    matches.isEmpty
                        ? 'Tap the heart on a recipe to keep it here.'
                        : '${matches.length} '
                              '${matches.length == 1 ? 'favorite' : 'favorites'}'
                              ' · ${matches.where(isReadyToCook).length} '
                              'ready to cook now',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 18),
                if (matches.isEmpty) ...[
                  const EmptyCard(
                    icon: Icons.favorite_border_rounded,
                    message: 'No saved recipes yet.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    key: const ValueKey('saved-browse-button'),
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (context) => RecipeBookScreen(
                          fridge: _fridge,
                          savedRecipes: _saved,
                          shopping: shopping,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.restaurant_menu_rounded),
                    label: const Text('Browse recipes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: recipeGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
                for (final match in matches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Dismissible(
                      key: ValueKey('saved-${match.recipe.id}'),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) =>
                          _remove(context, match.recipe.id, match.recipe.name),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFCDD2),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFC62828),
                        ),
                      ),
                      child: RecipeTile(
                        match: match,
                        isSaved: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => RecipeViewScreen(
                              recipeId: match.recipe.id,
                              fridge: _fridge,
                              savedRecipes: _saved,
                              shopping: shopping,
                            ),
                          ),
                        ),
                        onToggleSaved: () => _remove(
                          context,
                          match.recipe.id,
                          match.recipe.name,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
