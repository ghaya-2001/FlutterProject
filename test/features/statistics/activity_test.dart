import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/donations/domain/donation.dart';
import 'package:foodsaver/features/recipes/domain/saved_recipe.dart';
import 'package:foodsaver/features/statistics/domain/activity.dart';

import 'impact_test.dart' show donation, event;

void main() {
  final now = DateTime(2026, 11, 13, 18);

  test('builds every action, newest first, cooking grouped by recipe', () {
    final cookedAt = now.subtract(const Duration(hours: 1));
    final entries = buildActivity(
      history: [
        event('Tomatoes', 'Vegetables', 1, 'kg', cookedAt, recipe: 'Shakshuka'),
        event('Eggs', 'Dairy', 2, 'pcs', cookedAt, recipe: 'Shakshuka'),
        event(
          'Yogurt',
          'Dairy',
          1,
          'pcs',
          now.subtract(const Duration(hours: 3)),
          wasted: true,
        ),
        event('Milk', 'Dairy', 0.5, 'L', now.subtract(const Duration(days: 1))),
      ],
      donations: [
        donation(
          'Spinach',
          'Vegetables',
          1,
          'pack',
          collectedAt: now.subtract(const Duration(minutes: 10)),
        ),
      ],
      savedRecipes: [
        SavedRecipe(
          recipeId: 'pancakes',
          savedAt: now.subtract(const Duration(minutes: 30)),
        ),
        SavedRecipe(recipeId: 'removed-recipe', savedAt: now),
      ],
    );

    expect(entries.map((e) => e.title), [
      'Donation collected: Spinach',
      'Saved Pancakes',
      'Cooked Shakshuka',
      'Threw away Yogurt',
      'Ate Milk',
      'Donated Spinach',
    ]);
    final cooked = entries.firstWhere((e) => e.type == ActivityType.cooked);
    expect(cooked.subtitle, 'Tomatoes, Eggs');
    expect(
      entries.firstWhere((e) => e.title == 'Ate Milk').subtitle,
      '0.5 L · Dairy',
    );
  });

  test('two cookings of the same recipe stay separate', () {
    final entries = buildActivity(
      history: [
        event('Eggs', 'Dairy', 2, 'pcs', now, recipe: 'Pancakes'),
        event(
          'Eggs',
          'Dairy',
          2,
          'pcs',
          now.subtract(const Duration(days: 2)),
          recipe: 'Pancakes',
        ),
      ],
      donations: const [],
      savedRecipes: const [],
    );
    expect(entries.where((e) => e.type == ActivityType.cooked).length, 2);
  });

  test('a donation not collected yet only shows as donated', () {
    final entries = buildActivity(
      history: const [],
      donations: [
        donation('Bread', 'Bakery', 1, 'pcs', status: DonationStatus.reserved),
      ],
      savedRecipes: const [],
    );
    expect(entries.single.type, ActivityType.donated);
  });

  test('filters keep their types', () {
    final entries = buildActivity(
      history: [
        event('Milk', 'Dairy', 1, 'L', now),
        event('Yogurt', 'Dairy', 1, 'pcs', now, wasted: true),
      ],
      donations: [donation('Spinach', 'Vegetables', 1, 'pack')],
      savedRecipes: const [],
    );
    expect(entries.where(ActivityFilter.all.accepts).length, 4);
    expect(entries.where(ActivityFilter.wasted.accepts).length, 1);
    expect(entries.where(ActivityFilter.donations.accepts).length, 2);
    expect(entries.where(ActivityFilter.recipes.accepts), isEmpty);
  });
}
