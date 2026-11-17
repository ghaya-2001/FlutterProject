import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/recipes/domain/health_goal.dart';
import 'package:foodsaver/features/recipes/domain/nutrition.dart';
import 'package:foodsaver/features/statistics/domain/challenges.dart';
import 'package:foodsaver/features/statistics/domain/impact.dart';
import 'package:foodsaver/features/statistics/domain/nutrition_stats.dart';

import 'impact_test.dart' show donation, event;

void main() {
  final now = DateTime(2026, 11, 16, 18);
  final yesterday = now.subtract(const Duration(days: 1));
  final lastMonth = now.subtract(const Duration(days: 20));

  // Shakshuka: tomatoes + eggs recorded together = one meal.
  final history = [
    event('Tomatoes', 'Vegetables', 0.5, 'kg', now, recipe: 'Shakshuka'),
    event(
      'Eggs',
      'Dairy',
      2,
      'pcs',
      now.add(const Duration(seconds: 1)),
      recipe: 'Shakshuka',
    ),
    event(
      'Chicken breast',
      'Meat & Fish',
      0.3,
      'kg',
      yesterday,
      recipe: 'Yogurt chicken curry',
    ),
    event('Milk', 'Dairy', 1, 'L', lastMonth, recipe: 'Rice pudding'),
    event('Bread', 'Bakery', 1, 'pcs', now), // eaten, not cooked
    event('Old dish', 'Leftovers', 1, 'pcs', now, recipe: 'Removed recipe'),
  ];

  test('cookedMeals groups the foods of one cooking', () {
    final meals = cookedMeals(history);
    expect(meals.map((m) => m.recipe.id), [
      'shakshuka',
      'chicken-curry',
      'rice-pudding',
    ]);
  });

  test('cooking the same recipe twice counts two meals', () {
    final meals = cookedMeals([
      event('Tomatoes', 'Vegetables', 0.5, 'kg', now, recipe: 'Shakshuka'),
      event(
        'Tomatoes',
        'Vegetables',
        0.5,
        'kg',
        now.add(const Duration(hours: 2)),
        recipe: 'Shakshuka',
      ),
    ]);
    expect(meals.length, 2);
  });

  group('NutritionStats', () {
    NutritionStats stats(StatsPeriod period) =>
        NutritionStats.from(history: history, now: now, period: period);

    test('sums calories and macros of the period', () {
      final week = stats(StatsPeriod.week);
      expect(week.mealCount, 2);
      expect(week.total.kcal, 290 + 560);
      expect(week.total.protein, 17 + 40);
      expect(week.averageKcal, 425);

      final all = stats(StatsPeriod.allTime);
      expect(all.mealCount, 3);
      expect(all.total.kcal, 290 + 560 + 340);
    });

    test('counts tags and goals', () {
      final week = stats(StatsPeriod.week);
      expect(week.countTag(HealthTag.vegetarian), 1);
      expect(week.countTag(HealthTag.highProtein), 1);
      expect(week.countGoal(HealthGoal.loseWeight), 1);
      expect(week.countGoal(HealthGoal.none), 0);
    });

    test('empty history', () {
      final empty = NutritionStats([], now);
      expect(empty.isEmpty, isTrue);
      expect(empty.averageKcal, 0);
      expect(empty.total.kcal, 0);
    });
  });

  group('weeklyChallenges', () {
    HealthChallenge byKind(List<HealthChallenge> list, ChallengeKind kind) =>
        list.firstWhere((c) => c.kind == kind);

    test('progress comes from the last 7 days', () {
      final challenges = weeklyChallenges(
        history: history,
        donations: [donation('Rice', 'Pantry', 1, 'kg', collectedAt: now)],
        now: now,
      );
      expect(challenges.length, 5);
      expect(byKind(challenges, ChallengeKind.veggie).progress, 1);
      expect(byKind(challenges, ChallengeKind.protein).progress, 1);
      expect(byKind(challenges, ChallengeKind.light).progress, 1);
      expect(byKind(challenges, ChallengeKind.homeChef).progress, 2);
      // tomatoes, eggs, chicken, bread, leftovers + 1 donation
      final zeroWaste = byKind(challenges, ChallengeKind.zeroWaste);
      expect(zeroWaste.progress, 5); // capped at the target
      expect(zeroWaste.isDone, isTrue);
      expect(zeroWaste.ratio, 1);
    });

    test('throwing food away resets the zero waste challenge', () {
      final challenges = weeklyChallenges(
        history: [
          ...history,
          event('Yogurt', 'Dairy', 1, 'pcs', now, wasted: true),
        ],
        donations: const [],
        now: now,
      );
      expect(byKind(challenges, ChallengeKind.zeroWaste).progress, 0);
    });
  });
}
