import '../../fridge/domain/food_category.dart';
import 'donation.dart';

/// One line of the donation leaderboard: a food and how much of it was given.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.foodName,
    required this.unit,
    required this.category,
    required this.totalQuantity,
    required this.timesDonated,
  });

  final String foodName;
  final String unit;
  final FoodCategory category;

  /// Sum of the quantities of the completed donations, in [unit].
  final double totalQuantity;

  /// Number of completed donations of this food.
  final int timesDonated;
}

/// Ranks the foods of the completed (collected) donations, most donated
/// first.
///
/// Foods are grouped by name (ignoring case and spaces) and unit: quantities
/// in different units (kg and packs) cannot be added together, so they stay
/// on separate lines. "Most donated" means donated the most times; a tie is
/// broken by the larger quantity, then by name.
List<LeaderboardEntry> donationLeaderboard(Iterable<Donation> donations) {
  final completed =
      donations
          .where((donation) => donation.status == DonationStatus.collected)
          .toList()
        // Oldest first, so the newest spelling of a name is the one shown.
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  final groups = <String, LeaderboardEntry>{};
  for (final donation in completed) {
    final name = donation.foodName.trim();
    final key = '${name.toLowerCase()}|${donation.unit}';
    final previous = groups[key];
    groups[key] = LeaderboardEntry(
      foodName: name,
      unit: donation.unit,
      category: donation.category,
      totalQuantity: (previous?.totalQuantity ?? 0) + donation.quantity,
      timesDonated: (previous?.timesDonated ?? 0) + 1,
    );
  }

  return groups.values.toList()..sort((a, b) {
    final byTimes = b.timesDonated.compareTo(a.timesDonated);
    if (byTimes != 0) return byTimes;
    final byQuantity = b.totalQuantity.compareTo(a.totalQuantity);
    if (byQuantity != 0) return byQuantity;
    return a.foodName.toLowerCase().compareTo(b.foodName.toLowerCase());
  });
}
