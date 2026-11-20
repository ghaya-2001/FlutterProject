import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/list/data/budget_firestore.dart';
import 'package:foodsaver/features/list/data/budget_repository.dart';
import 'package:foodsaver/features/list/data/shopping_list_firestore.dart';
import 'package:foodsaver/features/list/data/shopping_list_repository.dart';
import 'package:foodsaver/features/list/domain/budget.dart';
import 'package:foodsaver/features/list/domain/purchase.dart';
import 'package:foodsaver/features/list/domain/shopping_category.dart';
import 'package:foodsaver/features/list/domain/shopping_item.dart';

void main() {
  final now = DateTime(2026, 11, 16, 10);
  late BudgetRepository budget;
  late ShoppingListRepository shopping;
  late String listId;

  ShoppingCategory category(String name) => shopping.categoryNamed(name)!;

  setUp(() {
    budget = BudgetRepository(clock: () => now);
    shopping = ShoppingListRepository(seed: false, budget: budget);
    listId = shopping.createList('Weekly').id;
  });

  group('budget', () {
    test('setBudget and removeBudget', () {
      budget.setBudget(300, BudgetPeriod.monthly);
      expect(budget.budget!.amount, 300);
      expect(budget.budget!.period, BudgetPeriod.monthly);

      budget.removeBudget();
      expect(budget.budget, isNull);
    });

    test('the budget must be positive', () {
      expect(
        () => budget.setBudget(0, BudgetPeriod.weekly),
        throwsArgumentError,
      );
      expect(
        () => budget.setBudget(-5, BudgetPeriod.weekly),
        throwsArgumentError,
      );
    });
  });

  group('purchases from the shopping list', () {
    test('ticking an item records its estimated total', () {
      final item = shopping.addItem(
        listId,
        name: 'Chicken',
        category: category('Meat & Fish'),
        quantity: 2,
        unit: 'kg',
        estimatedPrice: 18.5,
      );
      shopping.toggleBought(listId, item.id);

      final purchase = budget.purchases.single;
      expect(purchase.itemId, item.id);
      expect(purchase.name, 'Chicken');
      expect(purchase.categoryName, 'Meat & Fish');
      expect(purchase.amount, 37);
      expect(purchase.date, now);
    });

    test('an item without price is recorded without amount', () {
      final item = shopping.addItem(
        listId,
        name: 'Bread',
        category: category('Bakery'),
      );
      shopping.toggleBought(listId, item.id);
      expect(budget.purchases.single.hasPrice, isFalse);
    });

    test('unticking removes the purchase', () {
      final item = shopping.addItem(
        listId,
        name: 'Milk',
        category: category('Dairy'),
        estimatedPrice: 1.5,
      );
      shopping.toggleBought(listId, item.id);
      shopping.toggleBought(listId, item.id);
      expect(budget.purchases, isEmpty);
    });

    test('mark all as bought records every remaining item', () {
      final a = shopping.addItem(
        listId,
        name: 'Apples',
        category: category('Fruits'),
        estimatedPrice: 4,
      );
      shopping.addItem(listId, name: 'Rice', category: category('Pantry'));
      shopping.toggleBought(listId, a.id);
      shopping.markAllBought(listId);

      expect(budget.purchases.map((p) => p.name), ['Apples', 'Rice']);
    });

    test('clearing bought items keeps the spending history', () {
      final item = shopping.addItem(
        listId,
        name: 'Cheese',
        category: category('Dairy'),
        estimatedPrice: 9,
      );
      shopping.toggleBought(listId, item.id);
      shopping.clearBought(listId);

      expect(shopping.selectedList!.items, isEmpty);
      expect(budget.purchases.single.amount, 9);
    });

    test('the real price can be changed or removed', () {
      final item = shopping.addItem(
        listId,
        name: 'Fish',
        category: category('Meat & Fish'),
        estimatedPrice: 20,
      );
      shopping.toggleBought(listId, item.id);
      final id = budget.purchases.single.id;

      budget.updatePurchaseAmount(id, 23.4);
      expect(budget.purchaseById(id)!.amount, 23.4);

      budget.updatePurchaseAmount(id, null);
      expect(budget.purchaseById(id)!.hasPrice, isFalse);

      expect(() => budget.updatePurchaseAmount(id, -1), throwsArgumentError);
    });

    test('the report uses the items still to buy', () {
      budget.setBudget(100, BudgetPeriod.monthly);
      final bought = shopping.addItem(
        listId,
        name: 'Steak',
        category: category('Meat & Fish'),
        estimatedPrice: 30,
      );
      shopping.addItem(
        listId,
        name: 'Yogurt',
        category: category('Dairy'),
        quantity: 4,
        estimatedPrice: 0.75,
      );
      shopping.toggleBought(listId, bought.id);

      final report = budget.reportFor(shopping.allPendingItems);
      expect(report.totalSpent, 30);
      expect(report.estimatedToBuy, 3);
      expect(report.remaining, 70);
      expect(report.highest!.category, 'Meat & Fish');
    });

    test('clear forgets the previous user', () {
      budget.setBudget(50, BudgetPeriod.weekly);
      final item = shopping.addItem(
        listId,
        name: 'Eggs',
        category: category('Dairy'),
        estimatedPrice: 3,
      );
      shopping.toggleBought(listId, item.id);

      shopping.clear();
      expect(budget.budget, isNull);
      expect(budget.purchases, isEmpty);
    });
  });

  group('prices on shopping items', () {
    test('estimated total is unit price times quantity', () {
      final item = shopping.addItem(
        listId,
        name: 'Tomatoes',
        category: category('Vegetables'),
        quantity: 3,
        estimatedPrice: 2.5,
      );
      expect(item.estimatedTotal, 7.5);
    });

    test('merging a duplicate keeps the price unless a new one is given', () {
      shopping.addItem(
        listId,
        name: 'Milk',
        category: category('Dairy'),
        estimatedPrice: 1.5,
      );
      var merged = shopping.addItem(
        listId,
        name: 'milk',
        category: category('Dairy'),
      );
      expect(merged.quantity, 2);
      expect(merged.estimatedPrice, 1.5);

      merged = shopping.addItem(
        listId,
        name: 'Milk',
        category: category('Dairy'),
        estimatedPrice: 1.8,
      );
      expect(merged.estimatedPrice, 1.8);
    });

    test('negative prices are rejected', () {
      expect(
        () => shopping.addItem(
          listId,
          name: 'Oil',
          category: category('Pantry'),
          estimatedPrice: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Firestore maps', () {
    test('purchase round trip', () {
      final purchase = Purchase(
        id: 'p1',
        itemId: 'i1',
        listId: 'l1',
        name: 'Chicken',
        categoryName: 'Meat & Fish',
        quantity: 2,
        unit: 'kg',
        amount: 37,
        date: now,
      );
      final back = purchaseFromMap({...purchaseToMap(purchase), 'id': 'p1'});
      expect(back.name, 'Chicken');
      expect(back.categoryName, 'Meat & Fish');
      expect(back.amount, 37);
      expect(back.date, now);
    });

    test('a purchase without price stays without price', () {
      final back = purchaseFromMap({
        'id': 'p2',
        'name': 'Bread',
        'category': 'Bakery',
        'amount': null,
      });
      expect(back.hasPrice, isFalse);
      expect(back.quantity, 1);
    });

    test('budget round trip, and nothing stored means no budget', () {
      const budget = ShoppingBudget(amount: 250, period: BudgetPeriod.weekly);
      final back = budgetFromMap(budgetToMap(budget))!;
      expect(back.amount, 250);
      expect(back.period, BudgetPeriod.weekly);
      expect(budgetFromMap(null), isNull);
      expect(budgetFromMap({'amount': 0}), isNull);
    });

    test('item price round trip, and old items have no price', () {
      final item = ShoppingItem(
        id: 'i1',
        name: 'Milk',
        category: otherShoppingCategory,
        createdAt: now,
        estimatedPrice: 1.5,
      );
      final map = shoppingItemToMap(item);
      expect(map['estimatedPrice'], 1.5);
      expect(
        shoppingItemFromMap(map, (_) => otherShoppingCategory).estimatedPrice,
        1.5,
      );
      map.remove('estimatedPrice');
      expect(
        shoppingItemFromMap(map, (_) => otherShoppingCategory).estimatedPrice,
        isNull,
      );
    });
  });
}
