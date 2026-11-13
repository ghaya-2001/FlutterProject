import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../fridge/domain/recipes.dart';
import '../../list/data/shopping_list_repository.dart';
import '../data/saved_recipes_repository.dart';
import '../domain/recipe_search.dart';
import 'recipe_view_screen.dart';
import 'saved_recipes_screen.dart';
import 'widgets/recipe_tile.dart';

/// "Recipes" screen (Membre 5): every recipe of the app matched against the
/// fridge, with search, filters, suggestions and favorites.
class RecipeBookScreen extends StatefulWidget {
  const RecipeBookScreen({
    super.key,
    this.fridge,
    this.savedRecipes,
    this.shopping,
  });

  /// Default to the app-wide instances; injectable for tests.
  final FridgeRepository? fridge;
  final SavedRecipesRepository? savedRecipes;
  final ShoppingListRepository? shopping;

  @override
  State<RecipeBookScreen> createState() => _RecipeBookScreenState();
}

class _RecipeBookScreenState extends State<RecipeBookScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  RecipeFilter _filter = RecipeFilter.all;

  FridgeRepository get _fridge => widget.fridge ?? FridgeRepository.instance;
  SavedRecipesRepository get _saved =>
      widget.savedRecipes ?? SavedRecipesRepository.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _open(String recipeId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RecipeViewScreen(
          recipeId: recipeId,
          fridge: _fridge,
          savedRecipes: _saved,
          shopping: widget.shopping,
        ),
      ),
    );
  }

  void _toggleSaved(RecipeMatch match) {
    final saved = _saved.toggle(match.recipe.id);
    showAppSnackBar(
      context,
      saved
          ? '${match.recipe.name} added to your favorites'
          : '${match.recipe.name} removed from your favorites',
    );
  }

  void _openSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SavedRecipesScreen(
          fridge: _fridge,
          savedRecipes: _saved,
          shopping: widget.shopping,
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
            final all = matchAllRecipes(_fridge.items, _fridge.now);
            final results = searchRecipes(all, query: _query, filter: _filter);
            final showSuggestions =
                _query.trim().isEmpty && _filter == RecipeFilter.all;
            final suggestions = all.where(usesFridge).take(3).toList();
            final rest = showSuggestions
                ? results.where((m) => !suggestions.contains(m)).toList()
                : results;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              children: [
                ScreenHeader(
                  title: 'Recipes',
                  actions: [
                    HeaderIconButton(
                      key: const ValueKey('recipes-saved-button'),
                      icon: Icons.favorite_rounded,
                      tooltip: 'Saved recipes (${_saved.count})',
                      onPressed: _openSaved,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${all.length} recipes · '
                    '${all.where(isReadyToCook).length} ready to cook '
                    'with your fridge',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('recipes-search-field'),
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search a recipe or an ingredient',
                    prefixIcon: const Icon(Icons.search, color: recipeGreen),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in RecipeFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: ValueKey('recipes-filter-${filter.name}'),
                            label: Text(filter.label),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                            selectedColor: const Color(0xFFC8E6C9),
                            backgroundColor: Colors.white,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (showSuggestions && suggestions.isNotEmpty) ...[
                  const SectionTitle('Suggested for you'),
                  for (final match in suggestions) _tile(match),
                  const SectionTitle('All recipes'),
                ] else
                  const SizedBox(height: 18),
                if (rest.isEmpty && results.isEmpty)
                  const EmptyCard(
                    icon: Icons.search_off_rounded,
                    message: 'No recipe found. Try another word or filter.',
                  ),
                for (final match in rest) _tile(match),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tile(RecipeMatch match) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RecipeTile(
        match: match,
        isSaved: _saved.isSaved(match.recipe.id),
        onTap: () => _open(match.recipe.id),
        onToggleSaved: () => _toggleSaved(match),
      ),
    );
  }
}
