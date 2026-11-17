import 'package:flutter/material.dart';

import '../../../fridge/domain/recipes.dart';
import '../../domain/nutrition.dart';
import '../../domain/recipe_search.dart';

const recipeGreen = Color(0xFF2E7D32);
const recipeOrange = Color(0xFFE65100);
const recipeDark = Color(0xFF1B1B1B);

/// Card of one recipe: name, time, fridge foods used, tags, coverage and a
/// favorite (heart) button.
class RecipeTile extends StatelessWidget {
  const RecipeTile({
    super.key,
    required this.match,
    required this.isSaved,
    required this.onTap,
    required this.onToggleSaved,
    this.fitsGoal = false,
  });

  final RecipeMatch match;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;

  /// Shows a "Fits your goal" badge.
  final bool fitsGoal;

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    final used = match.used.values.map((food) => food.name).join(', ');
    final health = healthOf(recipe);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: ValueKey('recipe-tile-${recipe.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 6, 16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(recipe.icon, color: recipeOrange, size: 28),
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
                        color: recipeDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      used.isEmpty
                          ? '${recipe.minutes} min'
                          : '${recipe.minutes} min · $used',
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
                        if (health != null)
                          RecipeTag(
                            label: '${health.kcal} kcal',
                            color: const Color(0xFF00838F),
                          ),
                        if (fitsGoal)
                          const RecipeTag(
                            label: 'Fits your goal',
                            color: recipeOrange,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Coverage(value: match.coverage),
              IconButton(
                key: ValueKey('recipe-save-${recipe.id}'),
                tooltip: isSaved ? 'Remove from favorites' : 'Save recipe',
                onPressed: onToggleSaved,
                icon: Icon(
                  isSaved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isSaved ? const Color(0xFFE53935) : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small coloured label, e.g. "Ready to cook".
class RecipeTag extends StatelessWidget {
  const RecipeTag({super.key, required this.label, required this.color});

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

class _Coverage extends StatelessWidget {
  const _Coverage({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 5,
            backgroundColor: const Color(0xFFE8F5E9),
            color: recipeGreen,
          ),
          Center(
            child: Text(
              '${(value * 100).round()}%',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: recipeGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
