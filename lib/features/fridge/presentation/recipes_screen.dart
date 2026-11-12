import 'package:flutter/material.dart';

import '../../list/data/shopping_list_repository.dart';
import '../../list/domain/shopping_category.dart';
import '../data/fridge_repository.dart';
import '../domain/food_item.dart';
import '../domain/fridge_formatters.dart';
import '../domain/recipes.dart';

const _green = Color(0xFF2E7D32);
const _orange = Color(0xFFE65100);
const _dark = Color(0xFF1B1B1B);

/// "Cook now": recipes using the foods of the fridge, the ones saving the
/// foods about to expire first.
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({
    super.key,
    required this.repository,
    this.shoppingRepository,
  });

  final FridgeRepository repository;

  /// Defaults to [ShoppingListRepository.instance] (Membre 4).
  final ShoppingListRepository? shoppingRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: repository,
          builder: (context, _) {
            final matches = repository.recipeSuggestions;
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: _dark,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Cook now',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _dark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    'Recipes chosen from your fridge. The ones that save the '
                    'foods expiring soon come first.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 18),
                if (matches.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      'No recipe matches your fridge yet. Add some foods '
                      '(eggs, tomatoes, milk, pasta...) to get ideas.',
                      style: TextStyle(fontSize: 15, color: Colors.black54),
                    ),
                  )
                else
                  for (final match in matches) ...[
                    _RecipeCard(
                      match: match,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => RecipeDetailsScreen(
                            repository: repository,
                            recipeId: match.recipe.id,
                            shoppingRepository: shoppingRepository,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.match, required this.onTap});

  final RecipeMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(recipe.icon, color: _orange, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${recipe.minutes} min · '
                      '${match.used.values.map((f) => f.name).join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (match.urgentCount > 0)
                          _Tag(
                            label: 'Saves ${match.urgentCount} expiring',
                            color: _orange,
                          ),
                        _Tag(
                          label: match.canCook
                              ? 'Ready to cook'
                              : '${match.missing.length} missing',
                          color: match.canCook ? _green : Colors.black54,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: match.coverage,
                      strokeWidth: 5,
                      backgroundColor: const Color(0xFFE8F5E9),
                      color: _green,
                    ),
                    Center(
                      child: Text(
                        '${(match.coverage * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Default quantity used by a recipe for one food: one step of its unit
/// (1 pcs, 0.5 kg, 50 g...), never more than what is left.
double defaultCookAmount(FoodItem food) {
  final step = quantityStepFor(food.unit);
  return step > food.quantity ? food.quantity : step;
}

/// Ingredients, steps and the "I cooked it" action of one recipe.
class RecipeDetailsScreen extends StatefulWidget {
  const RecipeDetailsScreen({
    super.key,
    required this.repository,
    required this.recipeId,
    this.shoppingRepository,
  });

  final FridgeRepository repository;
  final String recipeId;
  final ShoppingListRepository? shoppingRepository;

  @override
  State<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  /// Quantity of each fridge food the user will cook with (food id → amount).
  final _amounts = <String, double>{};

  FridgeRepository get _repository => widget.repository;

  RecipeMatch? _currentMatch() {
    for (final match in _repository.recipeSuggestions) {
      if (match.recipe.id == widget.recipeId) {
        return match;
      }
    }
    return null;
  }

  double _amountFor(FoodItem food) {
    final amount = _amounts[food.id] ?? defaultCookAmount(food);
    return amount > food.quantity ? food.quantity : amount;
  }

  void _changeAmount(FoodItem food, int direction) {
    final step = quantityStepFor(food.unit);
    final next = ((_amountFor(food) + direction * step) * 1000).round() / 1000;
    setState(() => _amounts[food.id] = next.clamp(0, food.quantity).toDouble());
  }

  void _cook(RecipeMatch match) {
    final amounts = <String, double>{
      for (final food in match.used.values)
        if (_amountFor(food) > 0) food.id: _amountFor(food),
    };
    if (amounts.isEmpty) {
      _showSnackBar('Choose at least one ingredient');
      return;
    }
    // Taken before closing the screen: the message is shown on the previous one.
    final messenger = ScaffoldMessenger.of(context);
    _repository.cookRecipe(match.recipe, amounts);
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

  void _addMissingToList(RecipeMatch match) {
    final shopping =
        widget.shoppingRepository ?? ShoppingListRepository.instance;
    final list =
        shopping.selectedList ?? shopping.createList('Recipe ingredients');
    for (final ingredient in match.missing) {
      shopping.addItem(
        list.id,
        name: ingredient.name,
        category:
            shopping.categoryNamed(ingredient.category) ??
            otherShoppingCategory,
        note: 'For ${match.recipe.name}',
      );
    }
    _showSnackBar(
      '${match.missing.length} ingredient(s) added to "${list.name}"',
    );
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _repository,
          builder: (context, _) {
            final match = _currentMatch();
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: _dark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        match?.recipe.name ?? 'Recipe',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _dark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (match == null)
                  const Text(
                    'The ingredients of this recipe are no longer in your '
                    'fridge.',
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                  )
                else
                  ..._buildDetails(match),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildDetails(RecipeMatch match) {
    final recipe = match.recipe;
    final now = _repository.now;
    return [
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
            Icon(recipe.icon, size: 40, color: _orange),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '${recipe.minutes} min · '
                '${match.used.length}/${recipe.ingredients.length} '
                'ingredients in your fridge',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const _SectionTitle('From your fridge'),
      const SizedBox(height: 10),
      for (final entry in match.used.entries) ...[
        _IngredientRow(
          food: entry.value,
          amount: _amountFor(entry.value),
          urgent: entry.value.isPriority(now),
          expiryLabel: daysLeftLabel(entry.value, now),
          onMinus: () => _changeAmount(entry.value, -1),
          onPlus: () => _changeAmount(entry.value, 1),
        ),
        const SizedBox(height: 8),
      ],
      if (match.missing.isNotEmpty) ...[
        const SizedBox(height: 12),
        const _SectionTitle('Missing'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ingredient in match.missing)
              Chip(
                label: Text(ingredient.name),
                backgroundColor: Colors.white,
                side: BorderSide.none,
                shape: const StadiumBorder(),
              ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('add-missing-button'),
          onPressed: () => _addMissingToList(match),
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text('Add missing to shopping list'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _green,
            side: const BorderSide(color: _green),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
      const SizedBox(height: 20),
      const _SectionTitle('Steps'),
      const SizedBox(height: 10),
      for (var i = 0; i < recipe.steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: const Color(0xFFE8F5E9),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _green,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  recipe.steps[i],
                  style: const TextStyle(fontSize: 15, color: _dark),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 16),
      SizedBox(
        height: 56,
        child: ElevatedButton.icon(
          key: const ValueKey('cooked-button'),
          onPressed: () => _cook(match),
          icon: const Icon(Icons.soup_kitchen_rounded),
          label: const Text(
            'I cooked it',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'The quantities above are removed from your fridge and counted as '
        'eaten in your anti-waste stats.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.black45),
      ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: _dark,
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.food,
    required this.amount,
    required this.urgent,
    required this.expiryLabel,
    required this.onMinus,
    required this.onPlus,
  });

  final FoodItem food;
  final double amount;
  final bool urgent;
  final String expiryLabel;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: food.category.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(food.category.icon, size: 20, color: _dark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                Text(
                  urgent ? '$expiryLabel · use first' : expiryLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: urgent ? _orange : Colors.black54,
                    fontWeight: urgent ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Less',
            onPressed: amount > 0 ? onMinus : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: _green,
          ),
          Text(
            '${formatQuantity(amount)} ${food.unit}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: _dark),
          ),
          IconButton(
            tooltip: 'More',
            onPressed: amount < food.quantity ? onPlus : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: _green,
          ),
        ],
      ),
    );
  }
}
