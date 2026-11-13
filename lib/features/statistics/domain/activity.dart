import '../../donations/domain/donation.dart';
import '../../fridge/domain/fridge_event.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../../recipes/domain/extra_recipes.dart';
import '../../recipes/domain/saved_recipe.dart';

enum ActivityType {
  eaten('Eaten'),
  cooked('Cooked'),
  wasted('Wasted'),
  donated('Donated'),
  donationCollected('Collected'),
  recipeSaved('Recipe saved');

  const ActivityType(this.label);

  final String label;
}

/// Filters of the activity history.
enum ActivityFilter {
  all('All', {}),
  eaten('Eaten', {ActivityType.eaten}),
  cooked('Cooked', {ActivityType.cooked}),
  wasted('Wasted', {ActivityType.wasted}),
  donations('Donations', {
    ActivityType.donated,
    ActivityType.donationCollected,
  }),
  recipes('Recipes', {ActivityType.recipeSaved});

  const ActivityFilter(this.label, this.types);

  final String label;

  /// Types shown by this filter (empty for every type).
  final Set<ActivityType> types;

  bool accepts(ActivityEntry entry) =>
      types.isEmpty || types.contains(entry.type);
}

/// One action of the user, shown in the history.
class ActivityEntry {
  const ActivityEntry({
    required this.type,
    required this.at,
    required this.title,
    required this.subtitle,
  });

  final ActivityType type;
  final DateTime at;
  final String title;
  final String subtitle;
}

/// Foods of one cooked recipe are recorded together: events of the same
/// recipe less than this apart are shown as one "Cooked" action.
const _sameCookingGap = Duration(minutes: 1);

/// Every action of the user, newest first.
List<ActivityEntry> buildActivity({
  required List<FridgeEvent> history,
  required List<Donation> donations,
  required List<SavedRecipe> savedRecipes,
}) {
  final entries = <ActivityEntry>[];

  final events = [...history]..sort((a, b) => b.at.compareTo(a.at));
  final cooked = <FridgeEvent>[];
  void flushCooked() {
    if (cooked.isEmpty) return;
    entries.add(
      ActivityEntry(
        type: ActivityType.cooked,
        at: cooked.first.at,
        title: 'Cooked ${cooked.first.recipe}',
        subtitle: cooked.map((event) => event.foodName).toSet().join(', '),
      ),
    );
    cooked.clear();
  }

  for (final event in events) {
    if (event.recipe != null && !event.isWaste) {
      final sameCooking =
          cooked.isNotEmpty &&
          cooked.last.recipe == event.recipe &&
          cooked.last.at.difference(event.at).abs() < _sameCookingGap;
      if (!sameCooking) flushCooked();
      cooked.add(event);
      continue;
    }
    flushCooked();
    final amount =
        '${formatQuantity(event.quantity)} ${event.unit} · '
        '${event.category.name}';
    entries.add(
      event.isWaste
          ? ActivityEntry(
              type: ActivityType.wasted,
              at: event.at,
              title: 'Threw away ${event.foodName}',
              subtitle: amount,
            )
          : ActivityEntry(
              type: ActivityType.eaten,
              at: event.at,
              title: 'Ate ${event.foodName}',
              subtitle: amount,
            ),
    );
  }
  flushCooked();

  for (final donation in donations) {
    final amount = '${formatQuantity(donation.quantity)} ${donation.unit}';
    entries.add(
      ActivityEntry(
        type: ActivityType.donated,
        at: donation.createdAt,
        title: 'Donated ${donation.foodName}',
        subtitle: amount,
      ),
    );
    if (donation.status == DonationStatus.collected) {
      entries.add(
        ActivityEntry(
          type: ActivityType.donationCollected,
          at: donation.collectedAt ?? donation.createdAt,
          title: 'Donation collected: ${donation.foodName}',
          subtitle: '$amount saved from waste',
        ),
      );
    }
  }

  for (final saved in savedRecipes) {
    final recipe = recipeById(saved.recipeId);
    if (recipe == null) continue;
    entries.add(
      ActivityEntry(
        type: ActivityType.recipeSaved,
        at: saved.savedAt,
        title: 'Saved ${recipe.name}',
        subtitle: 'Added to your favorite recipes',
      ),
    );
  }

  entries.sort((a, b) => b.at.compareTo(a.at));
  return entries;
}
