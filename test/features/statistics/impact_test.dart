import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/donations/domain/donation.dart';
import 'package:foodsaver/features/fridge/domain/food_category.dart';
import 'package:foodsaver/features/fridge/domain/fridge_event.dart';
import 'package:foodsaver/features/statistics/domain/impact.dart';

FoodCategory _category(String name) =>
    defaultFoodCategories.firstWhere((c) => c.name == name);

FridgeEvent event(
  String food,
  String category,
  double quantity,
  String unit,
  DateTime at, {
  bool wasted = false,
  String? recipe,
}) => FridgeEvent(
  id: '$food-$at',
  type: wasted ? FridgeEventType.wasted : FridgeEventType.consumed,
  foodName: food,
  category: _category(category),
  quantity: quantity,
  unit: unit,
  at: at,
  recipe: recipe,
);

Donation donation(
  String food,
  String category,
  double quantity,
  String unit, {
  DonationStatus status = DonationStatus.collected,
  DateTime? collectedAt,
}) => Donation(
  id: 'd-$food',
  foodId: 'f-$food',
  foodName: food,
  category: _category(category),
  quantity: quantity,
  unit: unit,
  expiryDate: DateTime(2026, 11, 20),
  createdAt: DateTime(2026, 11, 1),
  status: status,
  collectedAt: collectedAt,
);

void main() {
  final now = DateTime(2026, 11, 13, 18);

  group('foodWeightKg', () {
    test('kg and L as they are, g and ml divided by 1000', () {
      expect(foodWeightKg(2, 'kg', 'Vegetables'), 2);
      expect(foodWeightKg(1.5, 'L', 'Dairy'), 1.5);
      expect(foodWeightKg(250, 'g', 'Pantry'), closeTo(0.25, 1e-9));
      expect(foodWeightKg(500, 'ml', 'Beverages'), closeTo(0.5, 1e-9));
    });

    test('pieces and packs use the average weight of the category', () {
      expect(foodWeightKg(6, 'pcs', 'Dairy'), closeTo(1.2, 1e-9));
      expect(foodWeightKg(2, 'pack', 'Meat & Fish'), closeTo(0.6, 1e-9));
      expect(foodWeightKg(4, 'pcs', 'My snacks'), closeTo(1.0, 1e-9));
      expect(foodWeightKg(0, 'kg', 'Fruits'), 0);
    });
  });

  group('meals and CO₂', () {
    test('a meal is about 400 g, at least 1 once something is saved', () {
      expect(mealsForKg(0), 0);
      expect(mealsForKg(0.1), 1);
      expect(mealsForKg(2), 5);
    });

    test('CO₂ uses the factor of the category', () {
      expect(co2ForKg(1, 'Meat & Fish'), 15);
      expect(co2ForKg(2, 'vegetables'), closeTo(1.6, 1e-9));
      expect(co2ForKg(1, 'Unknown'), defaultCo2KgPerKg);
    });
  });

  group('ImpactStats', () {
    final history = [
      event('Tomatoes', 'Vegetables', 1, 'kg', now), // eaten
      event(
        'Chicken breast',
        'Meat & Fish',
        0.5,
        'kg',
        now.subtract(const Duration(days: 1)),
        recipe: 'Lemon chicken & rice',
      ), // cooked
      event(
        'Yogurt',
        'Dairy',
        2,
        'pcs',
        now.subtract(const Duration(days: 2)),
        wasted: true,
      ),
      event(
        'Milk',
        'Dairy',
        1,
        'L',
        now.subtract(const Duration(days: 20)),
      ), // this month only
    ];
    final donations = [
      donation('Spinach', 'Vegetables', 2, 'pack', collectedAt: now),
      donation('Bread', 'Bakery', 1, 'pcs', status: DonationStatus.available),
    ];

    ImpactStats stats(StatsPeriod period) => ImpactStats.from(
      history: history,
      donations: donations,
      now: now,
      period: period,
    );

    test('counts saved foods (eaten, cooked, collected donations)', () {
      final all = stats(StatsPeriod.allTime);
      expect(all.savedCount, 4);
      expect(all.wastedCount, 1);
      expect(all.countFor(ImpactSource.eaten), 2);
      expect(all.countFor(ImpactSource.cooked), 1);
      expect(all.countFor(ImpactSource.donated), 1);
    });

    test('weights, meals, CO₂ and car distance', () {
      final all = stats(StatsPeriod.allTime);
      // 1 kg tomatoes + 0.5 kg chicken + 1 L milk + 2 packs of spinach (0.5)
      expect(all.savedKg, closeTo(3.0, 1e-9));
      expect(all.mealsSaved, 8); // 3.0 / 0.4 = 7.5
      // 1×0.8 + 0.5×15 + 1×4 + 0.5×0.8
      expect(all.co2AvoidedKg, closeTo(12.7, 1e-9));
      expect(all.carKm, closeTo(12.7 / 0.12, 1e-9));
      expect(all.wastedKg, closeTo(0.4, 1e-9));
      expect(all.co2LostKg, closeTo(1.6, 1e-9));
      expect(all.score, 80);
    });

    test('periods keep only their days', () {
      expect(stats(StatsPeriod.week).savedCount, 3);
      expect(stats(StatsPeriod.month).savedCount, 4);
      expect(stats(StatsPeriod.week).wastedCount, 1);
    });

    test('no history: no score and no meals', () {
      final empty = ImpactStats([], now);
      expect(empty.isEmpty, isTrue);
      expect(empty.score, isNull);
      expect(empty.mealsSaved, 0);
    });

    test('lastDays gives 7 days, oldest first, with saved and wasted', () {
      final days = stats(StatsPeriod.week).lastDays();
      expect(days.length, 7);
      expect(days.last.date, DateTime(2026, 11, 13));
      expect(days.last.saved, 2); // tomatoes + spinach donation
      expect(days[5].saved, 1); // chicken
      expect(days[4].wasted, 1); // yogurt
    });
  });

  test('formatAmount', () {
    expect(formatAmount(0), '0');
    expect(formatAmount(3), '3');
    expect(formatAmount(0.25), '0.3');
    expect(formatAmount(12.46), '12.5');
    expect(formatAmount(150.4), '150');
  });
}
