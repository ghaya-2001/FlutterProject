import 'package:flutter/material.dart';

import '../../data/health_profile_repository.dart';
import '../../domain/health_goal.dart';
import '../../domain/nutrition.dart';
import 'recipe_tile.dart';

const proteinColor = Color(0xFF1565C0);
const carbsColor = Color(0xFFF9A825);
const fatColor = Color(0xFFD84315);

/// Colour of a calorie level badge.
Color levelColor(CalorieLevel level) => switch (level) {
  CalorieLevel.light => recipeGreen,
  CalorieLevel.balanced => const Color(0xFF00838F),
  CalorieLevel.rich => recipeOrange,
};

/// Horizontal bar showing the share of energy from protein, carbs and fat.
class MacroBar extends StatelessWidget {
  const MacroBar({super.key, required this.nutrition, this.height = 10});

  final Nutrition nutrition;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shares = nutrition.energyShares;
    final parts = [
      (shares.protein, proteinColor),
      (shares.carbs, carbsColor),
      (shares.fat, fatColor),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (final (share, color) in parts)
              if (share > 0)
                Expanded(
                  flex: (share * 1000).round(),
                  child: ColoredBox(color: color),
                ),
            if (shares.protein + shares.carbs + shares.fat == 0)
              const Expanded(child: ColoredBox(color: Color(0xFFEEEEEE))),
          ],
        ),
      ),
    );
  }
}

/// "Protein 22 g", "Carbs 6 g" and "Fat 23 g" with their colour.
class MacroLegend extends StatelessWidget {
  const MacroLegend({super.key, required this.nutrition});

  final Nutrition nutrition;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Protein', nutrition.protein, proteinColor),
      ('Carbs', nutrition.carbs, carbsColor),
      ('Fat', nutrition.fat, fatColor),
    ];
    return Row(
      children: [
        for (final (label, grams, color) in items)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${grams.round()} g',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: recipeDark,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Calories, level, macros and diet tags of one recipe portion.
class NutritionCard extends StatelessWidget {
  const NutritionCard({super.key, required this.health, required this.goal});

  final RecipeHealth health;
  final HealthGoal goal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${health.kcal}',
                key: const ValueKey('recipe-view-kcal'),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: recipeDark,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text(
                  'kcal / portion',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
              const Spacer(),
              RecipeTag(
                label: health.level.label,
                color: levelColor(health.level),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MacroBar(nutrition: health.nutrition),
          const SizedBox(height: 12),
          MacroLegend(nutrition: health.nutrition),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (goal.fits(health))
                RecipeTag(label: 'Fits your goal', color: recipeOrange),
              for (final tag in health.tags)
                RecipeTag(label: tag.label, color: recipeGreen),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to choose the health goal; saves it in [repository].
Future<void> showHealthGoalPicker(
  BuildContext context,
  HealthProfileRepository repository,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your health goal',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: recipeDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Recipes that fit your goal are suggested first.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            for (final goal in HealthGoal.values)
              ListTile(
                key: ValueKey('health-goal-${goal.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  goal.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(goal.description),
                trailing: Icon(
                  repository.goal == goal
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: repository.goal == goal
                      ? recipeGreen
                      : Colors.black26,
                ),
                onTap: () {
                  repository.setGoal(goal);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    ),
  );
}
