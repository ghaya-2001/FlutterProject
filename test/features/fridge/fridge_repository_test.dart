import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/fridge/domain/food_category.dart';
import 'package:foodsaver/features/fridge/domain/food_item.dart';
import 'package:foodsaver/features/fridge/domain/fridge_formatters.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late FridgeRepository repository;

  FoodCategory category(String name) => repository.categoryNamed(name)!;

  FoodItem add(
    String name, {
    String categoryName = 'Dairy',
    double quantity = 1,
    String unit = 'pcs',
    int daysLeft = 5,
  }) {
    return repository.addFood(
      name: name,
      category: category(categoryName),
      quantity: quantity,
      unit: unit,
      expiryDate: today.add(Duration(days: daysLeft)),
    );
  }

  setUp(() {
    repository = FridgeRepository(seed: false, clock: () => today);
  });

  group('add / edit / delete', () {
    test('addFood stores a trimmed food and notifies listeners', () {
      var notifications = 0;
      repository.addListener(() => notifications++);

      final item = repository.addFood(
        name: '  Cheese ',
        category: category('Dairy'),
        quantity: 2,
        unit: 'pcs',
        expiryDate: DateTime(2026, 11, 1, 18),
        note: ' opened ',
      );

      expect(item.name, 'Cheese');
      expect(item.note, 'opened');
      expect(item.expiryDate, DateTime(2026, 11, 1));
      expect(repository.totalCount, 1);
      expect(notifications, 1);
    });

    test('addFood validates name and quantity', () {
      expect(() => add('  '), throwsArgumentError);
      expect(() => add('Milk', quantity: 0), throwsArgumentError);
    });

    test('updateFood edits an existing food', () {
      final item = add('Milk');
      repository.updateFood(
        item.copyWith(name: 'Oat milk', quantity: 2, unit: 'L'),
      );

      final updated = repository.itemById(item.id)!;
      expect(updated.name, 'Oat milk');
      expect(updated.quantity, 2);
      expect(updated.unit, 'L');
    });

    test('deleteFood and restoreFood support undo', () {
      add('A');
      final b = add('B');
      add('C');

      final index = repository.deleteFood(b.id);
      expect(index, 1);
      expect(repository.itemById(b.id), isNull);

      repository.restoreFood(b, index);
      expect(repository.items.map((item) => item.name), ['A', 'B', 'C']);
    });
  });

  group('stock after consumption', () {
    test('consume reduces the quantity', () {
      final eggs = add('Eggs', quantity: 6);

      final remaining = repository.consume(eggs.id, 2);

      expect(remaining, 4);
      expect(repository.itemById(eggs.id)!.quantity, 4);
    });

    test('consume handles decimals without rounding errors', () {
      final rice = add('Rice', quantity: 1, unit: 'kg');

      expect(repository.consume(rice.id, 0.7), 0.3);
      expect(repository.consume(rice.id, 0.1), 0.2);
    });

    test('consuming everything removes the food', () {
      final yogurt = add('Yogurt', quantity: 1);

      expect(repository.consume(yogurt.id, 1), 0);
      expect(repository.itemById(yogurt.id), isNull);
    });

    test('consume rejects invalid amounts', () {
      final milk = add('Milk');
      expect(() => repository.consume(milk.id, 0), throwsArgumentError);
    });
  });

  group('expiry dates and priority', () {
    test('daysLeft and status are computed from calendar days', () {
      final expired = add('Old', daysLeft: -2);
      final todayItem = add('Today', daysLeft: 0);
      final soon = add('Soon', daysLeft: 3);
      final fresh = add('Fresh', daysLeft: 4);

      expect(expired.daysLeft(today), -2);
      expect(expired.status(today), ExpiryStatus.expired);
      expect(todayItem.status(today), ExpiryStatus.today);
      expect(soon.status(today), ExpiryStatus.soon);
      expect(fresh.status(today), ExpiryStatus.fresh);

      expect(soon.isPriority(today), isTrue);
      expect(fresh.isPriority(today), isFalse);
    });

    test('counters: available, priority and expired', () {
      add('Old', daysLeft: -1);
      add('Today', daysLeft: 0);
      add('Fresh', daysLeft: 10);

      expect(repository.totalCount, 3);
      expect(repository.availableCount, 2);
      expect(repository.priorityCount, 2);
      expect(repository.expiredCount, 1);
    });

    test('daysLeftLabel', () {
      expect(daysLeftLabel(add('a', daysLeft: -1), today), 'Expired 1 day ago');
      expect(daysLeftLabel(add('b', daysLeft: 0), today), 'Today');
      expect(daysLeftLabel(add('c', daysLeft: 1), today), '1 day left');
      expect(daysLeftLabel(add('d', daysLeft: 5), today), '5 days left');
      expect(daysLeftLabel(add('e', daysLeft: 21), today), '3 weeks left');
    });
  });

  group('search, filter and sort', () {
    setUp(() {
      add('Milk', daysLeft: 5);
      add('Spinach', categoryName: 'Vegetables', daysLeft: 1);
      add('Apple', categoryName: 'Fruits', daysLeft: 9);
    });

    test('default sort is by expiry date', () {
      expect(repository.query().map((item) => item.name), [
        'Spinach',
        'Milk',
        'Apple',
      ]);
    });

    test('sort by name and recently added', () {
      expect(repository.query(sort: FridgeSort.name).map((i) => i.name), [
        'Apple',
        'Milk',
        'Spinach',
      ]);
      expect(
        repository.query(sort: FridgeSort.recentlyAdded).length,
        repository.totalCount,
      );
    });

    test('search matches name and category, case insensitive', () {
      expect(repository.query(search: 'SPIN').single.name, 'Spinach');
      expect(repository.query(search: 'fruit').single.name, 'Apple');
      expect(repository.query(search: 'xyz'), isEmpty);
    });

    test('filter by category', () {
      expect(repository.query(category: category('Dairy')).single.name, 'Milk');
    });
  });

  group('categories', () {
    test('addCategory creates a custom category before "Other"', () {
      final sauces = repository.addCategory('Sauces');

      expect(sauces.isCustom, isTrue);
      expect(repository.categories.last, otherFoodCategory);
      expect(() => repository.addCategory('sauces'), throwsArgumentError);
    });

    test('removeCategory moves its foods to "Other"', () {
      final sauces = repository.addCategory('Sauces');
      final ketchup = repository.addFood(
        name: 'Ketchup',
        category: sauces,
        quantity: 1,
        unit: 'pcs',
        expiryDate: today.add(const Duration(days: 60)),
      );

      repository.removeCategory(sauces);

      expect(repository.hasCategoryNamed('Sauces'), isFalse);
      expect(repository.itemById(ketchup.id)!.category, otherFoodCategory);
    });

    test('default categories cannot be removed', () {
      expect(
        () => repository.removeCategory(category('Dairy')),
        throwsArgumentError,
      );
    });
  });

  test('formatQuantity drops useless decimals', () {
    expect(formatQuantity(2), '2');
    expect(formatQuantity(0.5), '0.5');
    expect(formatQuantity(1.25), '1.25');
  });
}
