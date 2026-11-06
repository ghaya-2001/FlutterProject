import 'package:flutter/material.dart';

import 'fridge_event.dart';
import 'fridge_stats.dart';

/// A badge earned by eating food instead of wasting it.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.current,
    required this.goal,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int current;
  final int goal;

  bool get isUnlocked => current >= goal;

  /// From 0 to 1.
  double get progress => goal == 0 ? 1 : (current / goal).clamp(0, 1);
}

/// Every badge with its progress, unlocked ones first.
List<Achievement> achievementsFor(List<FridgeEvent> history, DateTime now) {
  final eaten = history.where((event) => !event.isWaste).toList();
  final stats = FridgeStats(history, now);

  // Foods eaten on their last day (or the day before).
  final rescued = eaten.where((event) {
    final days = event.daysLeft;
    return days != null && days >= 0 && days <= 1;
  }).length;

  // One cooking session = every ingredient recorded at the same moment.
  final cooked = {
    for (final event in eaten)
      if (event.recipe != null) '${event.recipe}@${event.at}',
  }.length;

  final categories = {for (final event in eaten) event.category}.length;

  final achievements = [
    Achievement(
      id: 'first-bite',
      title: 'First bite',
      description: 'Eat a food from your fridge',
      icon: Icons.restaurant_rounded,
      current: eaten.length,
      goal: 1,
    ),
    Achievement(
      id: 'food-saver',
      title: 'Food saver',
      description: 'Eat 10 foods from your fridge',
      icon: Icons.savings_rounded,
      current: eaten.length,
      goal: 10,
    ),
    Achievement(
      id: 'last-minute',
      title: 'Last-minute rescue',
      description: 'Eat 5 foods on their last day',
      icon: Icons.timer_rounded,
      current: rescued,
      goal: 5,
    ),
    Achievement(
      id: 'chef',
      title: 'Anti-waste chef',
      description: 'Cook 3 suggested recipes',
      icon: Icons.soup_kitchen_rounded,
      current: cooked,
      goal: 3,
    ),
    Achievement(
      id: 'balanced',
      title: 'Balanced diet',
      description: 'Eat foods from 5 categories',
      icon: Icons.pie_chart_rounded,
      current: categories,
      goal: 5,
    ),
    Achievement(
      id: 'zero-waste-week',
      title: 'Zero-waste week',
      description: '7 days in a row without waste',
      icon: Icons.local_fire_department_rounded,
      current: stats.daysWithoutWaste ?? 0,
      goal: 7,
    ),
    Achievement(
      id: 'champion',
      title: 'Anti-waste champion',
      description: 'Eat 50 foods from your fridge',
      icon: Icons.emoji_events_rounded,
      current: eaten.length,
      goal: 50,
    ),
  ];

  // Stable sort: unlocked first, then the closest to being unlocked.
  final indexed = achievements.asMap().entries.toList()
    ..sort((a, b) {
      final unlocked =
          (b.value.isUnlocked ? 1 : 0) - (a.value.isUnlocked ? 1 : 0);
      if (unlocked != 0) return unlocked;
      final byProgress = b.value.progress.compareTo(a.value.progress);
      return byProgress != 0 ? byProgress : a.key.compareTo(b.key);
    });
  return [for (final entry in indexed) entry.value];
}
