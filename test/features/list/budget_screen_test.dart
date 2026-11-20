import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/list/data/budget_repository.dart';
import 'package:foodsaver/features/list/data/shopping_list_repository.dart';
import 'package:foodsaver/features/list/domain/budget.dart';
import 'package:foodsaver/features/list/presentation/budget_screen.dart';
import 'package:foodsaver/features/list/presentation/list_screen.dart';

void main() {
  final now = DateTime(2026, 11, 16, 10);
  late BudgetRepository budget;
  late ShoppingListRepository shopping;
  late String listId;

  setUp(() {
    budget = BudgetRepository(clock: () => now);
    shopping = ShoppingListRepository(seed: false, budget: budget);
    listId = shopping.createList('Weekly').id;
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
  }

  void buy(String name, String category, double price, {int quantity = 1}) {
    final item = shopping.addItem(
      listId,
      name: name,
      category: shopping.categoryNamed(category)!,
      quantity: quantity,
      estimatedPrice: price,
    );
    shopping.toggleBought(listId, item.id);
  }

  testWidgets('shows the overview, the breakdown and the insights', (
    tester,
  ) async {
    budget.setBudget(200, BudgetPeriod.monthly);
    buy('Steak', 'Meat & Fish', 60);
    buy('Salmon', 'Meat & Fish', 20);
    buy('Carrots', 'Vegetables', 10, quantity: 2);
    shopping.addItem(
      listId,
      name: 'Cheese',
      category: shopping.categoryNamed('Dairy')!,
      estimatedPrice: 12,
    );

    await pump(tester, BudgetScreen(budget: budget, shopping: shopping));

    expect(find.text('November 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('budget-remaining')), findsOneWidget);
    expect(find.text('100.00 DT left'), findsOneWidget);
    expect(find.text('50% of your monthly budget used'), findsOneWidget);
    expect(find.text('≈ 12.00 DT'), findsOneWidget);

    expect(find.byKey(const ValueKey('spending-breakdown')), findsOneWidget);
    expect(find.text('Highest'), findsOneWidget);
    expect(find.text('Lowest'), findsOneWidget);
    expect(find.text('80% of spending · 40% of budget'), findsOneWidget);

    expect(
      find.textContaining('Meat & Fish is your highest spending category'),
      findsOneWidget,
    );
    expect(find.text('You have 100.00 DT remaining.'), findsOneWidget);

    // The purchases are listed at the bottom of the screen.
    await tester.scrollUntilVisible(find.text('Steak'), 300);
    expect(find.text('Steak'), findsOneWidget);
  });

  testWidgets('sets a budget from the empty state', (tester) async {
    await pump(tester, BudgetScreen(budget: budget, shopping: shopping));

    expect(find.text('No budget yet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('set-budget-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Weekly'));
    await tester.enterText(
      find.byKey(const ValueKey('budget-amount-field')),
      '75,5',
    );
    await tester.tap(find.byKey(const ValueKey('save-budget-button')));
    await tester.pumpAndSettle();

    expect(budget.budget!.amount, 75.5);
    expect(budget.budget!.period, BudgetPeriod.weekly);
    expect(find.text('75.50 DT left'), findsOneWidget);
  });

  testWidgets('a purchase without price can be completed', (tester) async {
    final item = shopping.addItem(
      listId,
      name: 'Bread',
      category: shopping.categoryNamed('Bakery')!,
    );
    shopping.toggleBought(listId, item.id);

    await pump(tester, BudgetScreen(budget: budget, shopping: shopping));
    expect(find.text('Add price'), findsOneWidget);

    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('purchase-price-field')),
      '1.2',
    );
    await tester.tap(find.byKey(const ValueKey('save-price-button')));
    await tester.pumpAndSettle();

    expect(budget.purchases.single.amount, 1.2);
    expect(find.text('1.20 DT'), findsWidgets);
  });

  testWidgets('the list shows prices and the budget card', (tester) async {
    budget.setBudget(100, BudgetPeriod.monthly);
    shopping.addItem(
      listId,
      name: 'Apples',
      category: shopping.categoryNamed('Fruits')!,
      quantity: 2,
      estimatedPrice: 3,
    );

    await pump(tester, ListScreen(repository: shopping));

    expect(find.byKey(const ValueKey('budget-card')), findsOneWidget);
    expect(find.text('100.00 DT left this month'), findsOneWidget);
    expect(find.textContaining('≈ 6.00 DT'), findsWidgets);

    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('budget-card')).hitTestable(),
            matching: find.byType(Text),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Budget & spending'), findsOneWidget);
  });

  testWidgets('ticking an item shows the recorded price', (tester) async {
    shopping.addItem(
      listId,
      name: 'Apples',
      category: shopping.categoryNamed('Fruits')!,
      quantity: 2,
      estimatedPrice: 3,
    );

    await pump(tester, ListScreen(repository: shopping));
    await tester.tap(find.byTooltip('Mark as bought'));
    await tester.pump();

    expect(find.text('Apples bought · 6.00 DT'), findsOneWidget);
    expect(find.text('Edit price'), findsOneWidget);
    expect(budget.purchases.single.amount, 6);
  });

  testWidgets('the Add item screen saves an estimated price', (tester) async {
    await pump(tester, ListScreen(repository: shopping));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('item-name-field')),
      'Olive oil',
    );
    await tester.tap(find.byKey(const ValueKey('quantity-increase')));
    await tester.enterText(find.byKey(const ValueKey('item-price-field')), '8');
    await tester.pump();
    expect(find.text('Estimated total: 16.00 DT'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save-item-button')));
    await tester.pumpAndSettle();

    final item = shopping.selectedList!.items.single;
    expect(item.estimatedPrice, 8);
    expect(item.estimatedTotal, 16);
  });
}
