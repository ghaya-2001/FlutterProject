import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/expiry/domain/expiry_alerts.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/fridge/domain/food_category.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late FridgeRepository fridge;

  // Seeded fridge on [today]: Yogurt (0), Chicken breast (1), Spinach (2),
  // Tomatoes (3), Milk (5), Lemon (7), Eggs (14).
  setUp(() {
    fridge = FridgeRepository(clock: () => today);
  });

  test('alert levels follow the 7 / 3 / 0 day rules', () {
    ExpiryAlertLevel? levelOf(String name) => alertLevelFor(
      fridge.items.firstWhere((item) => item.name == name),
      today,
    );

    expect(levelOf('Yogurt'), ExpiryAlertLevel.today);
    expect(levelOf('Chicken breast'), ExpiryAlertLevel.threeDays);
    expect(levelOf('Tomatoes'), ExpiryAlertLevel.threeDays);
    expect(levelOf('Milk'), ExpiryAlertLevel.sevenDays);
    expect(levelOf('Lemon'), ExpiryAlertLevel.sevenDays);
    expect(levelOf('Eggs'), isNull);
  });

  test('expired food gets the expired level', () {
    final item = fridge.addFood(
      name: 'Old cheese',
      category: otherFoodCategory,
      quantity: 1,
      unit: 'pcs',
      expiryDate: today.subtract(const Duration(days: 2)),
    );
    expect(alertLevelFor(item, today), ExpiryAlertLevel.expired);
    expect(expiryAlerts(fridge.items, today).first.item.name, 'Old cheese');
  });

  test('expiring soon lists non-expired food within 7 days, soonest first', () {
    final names = expiringSoon(fridge.items, today).map((i) => i.name);
    expect(names, [
      'Yogurt',
      'Chicken breast',
      'Spinach',
      'Tomatoes',
      'Milk',
      'Lemon',
    ]);
  });

  test(
    'phone alerts are planned at 9:00, 7 and 3 days before and on the day',
    () {
      final eggs = fridge.items.firstWhere((item) => item.name == 'Eggs');
      final moments = alertMomentsFor(eggs, today);
      final expiry = eggs.expiryDate;
      expect(moments, [
        DateTime(expiry.year, expiry.month, expiry.day - 7, 9),
        DateTime(expiry.year, expiry.month, expiry.day - 3, 9),
        DateTime(expiry.year, expiry.month, expiry.day, 9),
      ]);

      // Spinach expires in 2 days: only the same-day alert is still to come.
      final spinach = fridge.items.firstWhere((item) => item.name == 'Spinach');
      expect(alertMomentsFor(spinach, today), hasLength(1));
    },
  );
}
