import '../../donations/domain/donation.dart';
import '../../fridge/domain/fridge_event.dart';
import '../../recipes/domain/nutrition.dart';
import 'impact.dart';
import 'nutrition_stats.dart';

enum ChallengeKind { veggie, protein, light, homeChef, zeroWaste }

/// A healthy challenge of the week, with its progress.
///
/// Never stored: computed from the last 7 days of history every time.
class HealthChallenge {
  const HealthChallenge({
    required this.kind,
    required this.title,
    required this.description,
    required this.target,
    required int progress,
  }) : progress = progress > target ? target : progress;

  final ChallengeKind kind;
  final String title;
  final String description;
  final int target;
  final int progress;

  bool get isDone => progress >= target;

  /// From 0 to 1.
  double get ratio => progress / target;
}

/// The challenges of the current week (the last 7 days, today included).
List<HealthChallenge> weeklyChallenges({
  required List<FridgeEvent> history,
  required List<Donation> donations,
  required DateTime now,
}) {
  final nutrition = NutritionStats.from(
    history: history,
    now: now,
    period: StatsPeriod.week,
  );
  final impact = ImpactStats.from(
    history: history,
    donations: donations,
    now: now,
    period: StatsPeriod.week,
  );
  return [
    HealthChallenge(
      kind: ChallengeKind.veggie,
      title: 'Veggie week',
      description: 'Cook 3 vegetarian recipes',
      target: 3,
      progress: nutrition.countTag(HealthTag.vegetarian),
    ),
    HealthChallenge(
      kind: ChallengeKind.protein,
      title: 'Protein power',
      description: 'Cook 2 high-protein recipes',
      target: 2,
      progress: nutrition.countTag(HealthTag.highProtein),
    ),
    HealthChallenge(
      kind: ChallengeKind.light,
      title: 'Light & tasty',
      description: 'Cook 3 meals under $lowCalorieKcal kcal',
      target: 3,
      progress: nutrition.countTag(HealthTag.lowCalorie),
    ),
    HealthChallenge(
      kind: ChallengeKind.homeChef,
      title: 'Home chef',
      description: 'Cook 5 recipes from your fridge',
      target: 5,
      progress: nutrition.mealCount,
    ),
    HealthChallenge(
      kind: ChallengeKind.zeroWaste,
      title: 'Zero waste',
      description: 'Save 5 foods and throw nothing away',
      target: 5,
      progress: impact.wastedCount == 0 ? impact.savedCount : 0,
    ),
  ];
}
