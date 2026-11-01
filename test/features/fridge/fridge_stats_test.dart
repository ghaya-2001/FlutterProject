import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/fridge/domain/food_category.dart';
import 'package:foodsaver/features/fridge/domain/food_item.dart';
import 'package:foodsaver/features/fridge/domain/fridge_event.dart';
import 'package:foodsaver/features/fridge/domain/fridge_stats.dart';
import 'package:foodsaver/features/fridge/presentation/food_details_screen.dart';
import 'package:foodsaver/features/fridge/presentation/fridge_stats_screen.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  final dairy = defaultFoodCategories.firstWhere((c) => c.name == 'Dairy');
  final fruits = defaultFoodCategories.firstWhere((c) => c.name == 'Fruits');

  FridgeEvent event(
    FridgeEventType type, {
    int daysAgo = 0,
    FoodCategory? category,
  }) {
    return FridgeEvent(
      id: 'event-$type-$daysAgo-${category?.name}',
      type: type,
      foodName: 'Food',
      category: category ?? dairy,
      quantity: 1,
      unit: 'pcs',
      at: today.subtract(Duration(days: daysAgo)),
    );
  }

  group('FridgeStats', () {
    test('is empty without history', () {
      final stats = FridgeStats(const [], today);
      expect(stats.isEmpty, isTrue);
      expect(stats.score, isNull);
      expect(stats.daysWithoutWaste, isNull);
    });

    test('score is the share of eaten foods', () {
      final stats = FridgeStats([
        event(FridgeEventType.consumed),
        event(FridgeEventType.consumed, daysAgo: 1),
        event(FridgeEventType.consumed, daysAgo: 2),
        event(FridgeEventType.wasted, daysAgo: 3),
      ], today);
      expect(stats.consumedCount, 3);
      expect(stats.wastedCount, 1);
      expect(stats.score, 75);
      expect(stats.daysWithoutWaste, 3);
    });

    test('last days are grouped per calendar day, oldest first', () {
      final stats = FridgeStats([
        event(FridgeEventType.consumed),
        event(FridgeEventType.wasted),
        event(FridgeEventType.consumed, daysAgo: 6),
        event(FridgeEventType.consumed, daysAgo: 9),
      ], today);
      final days = stats.lastDays;
      expect(days, hasLength(7));
      expect(days.first.date, DateTime(2026, 10, 18));
      expect(days.first.consumed, 1);
      expect(days.last.date, DateTime(2026, 10, 24));
      expect(days.last.consumed, 1);
      expect(days.last.wasted, 1);
      expect(days.fold<int>(0, (sum, d) => sum + d.total), 3);
    });

    test('wasted categories are sorted by count', () {
      final stats = FridgeStats([
        event(FridgeEventType.wasted, category: dairy),
        event(FridgeEventType.wasted, daysAgo: 1, category: fruits),
        event(FridgeEventType.wasted, daysAgo: 2, category: fruits),
        event(FridgeEventType.consumed, category: dairy),
      ], today);
      final entries = stats.wastedByCategory;
      expect(entries.first.key, fruits);
      expect(entries.first.value, 2);
      expect(entries.last.key, dairy);
    });

    test('never wasted counts days since the first event', () {
      final stats = FridgeStats([
        event(FridgeEventType.consumed, daysAgo: 4),
        event(FridgeEventType.consumed, daysAgo: 1),
      ], today);
      expect(stats.daysWithoutWaste, 4);
      expect(stats.score, 100);
    });
  });

  group('history in the repository', () {
    late FridgeRepository repository;

    FoodItem add(String name, {int daysLeft = 5, double quantity = 2}) {
      return repository.addFood(
        name: name,
        category: dairy,
        quantity: quantity,
        unit: 'pcs',
        expiryDate: today.add(Duration(days: daysLeft)),
      );
    }

    setUp(() {
      repository = FridgeRepository(seed: false, clock: () => today);
    });

    test('consume records what was eaten', () {
      final milk = add('Milk', quantity: 3);
      repository.consume(milk.id, 1);
      repository.consume(milk.id, 5);
      expect(repository.history, hasLength(2));
      expect(repository.history.first.quantity, 2);
      expect(repository.history.every((e) => !e.isWaste), isTrue);
    });

    test('consume without record (donations) adds nothing', () {
      final milk = add('Milk');
      repository.consume(milk.id, 1, record: false);
      expect(repository.history, isEmpty);
    });

    test('throwAway removes the food and records waste', () {
      final yogurt = add('Yogurt', daysLeft: -2);
      repository.throwAway(yogurt.id);
      expect(repository.itemById(yogurt.id), isNull);
      expect(repository.history.single.isWaste, isTrue);
      expect(repository.stats.score, 0);
      expect(() => repository.throwAway('missing'), throwsArgumentError);
    });

    test('deleteFood is a correction and records nothing', () {
      final milk = add('Milk');
      repository.deleteFood(milk.id);
      expect(repository.history, isEmpty);
    });
  });

  group('screens', () {
    late FridgeRepository repository;

    setUp(() {
      repository = FridgeRepository(seed: false, clock: () => today);
    });

    testWidgets('stats screen shows an empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: FridgeStatsScreen(repository: repository)),
      );
      expect(find.text('No statistics yet'), findsOneWidget);
    });

    testWidgets('stats screen shows score and activity', (tester) async {
      final milk = repository.addFood(
        name: 'Milk',
        category: dairy,
        quantity: 1,
        unit: 'L',
        expiryDate: today.add(const Duration(days: 3)),
      );
      final cheese = repository.addFood(
        name: 'Cheese',
        category: dairy,
        quantity: 1,
        unit: 'pcs',
        expiryDate: today.subtract(const Duration(days: 1)),
      );
      repository.consume(milk.id, 1);
      repository.throwAway(cheese.id);

      await tester.pumpWidget(
        MaterialApp(home: FridgeStatsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('50%'), findsOneWidget);
      expect(find.text('1 eaten'), findsOneWidget);
      expect(find.text('1 wasted'), findsOneWidget);
      expect(find.text('Most wasted categories'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Cheese'), 200);
      expect(find.text('Cheese'), findsOneWidget);
    });

    testWidgets('expired food can be thrown away from details', (tester) async {
      final cheese = repository.addFood(
        name: 'Cheese',
        category: dairy,
        quantity: 1,
        unit: 'pcs',
        expiryDate: today.subtract(const Duration(days: 1)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FoodDetailsScreen(repository: repository, foodId: cheese.id),
        ),
      );

      expect(find.byKey(const ValueKey('donate-food-button')), findsNothing);
      final throwAway = find.byKey(const ValueKey('throw-away-button'));
      await tester.scrollUntilVisible(throwAway, 200);
      await tester.tap(throwAway);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Throw away').last);
      await tester.pumpAndSettle();

      expect(repository.itemById(cheese.id), isNull);
      expect(repository.history.single.isWaste, isTrue);
    });
  });
}
