import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/list/data/shopping_list_repository.dart';
import 'package:foodsaver/features/list/presentation/list_screen.dart';

void main() {
  late ShoppingListRepository repository;

  Future<void> pumpListScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: ListScreen(repository: repository)),
    );
  }

  setUp(() {
    repository = ShoppingListRepository();
  });

  testWidgets('shows the seeded list grouped into to-buy and bought', (
    tester,
  ) async {
    await pumpListScreen(tester);

    expect(find.text('Shopping list'), findsOneWidget);
    expect(find.text('Weekly groceries (3)'), findsOneWidget);
    expect(find.text('To buy'), findsOneWidget);
    expect(find.text('Bought'), findsOneWidget);
    expect(find.text('3 item(s) left to buy'), findsOneWidget);
    expect(find.text('2/5 bought'), findsOneWidget);
  });

  testWidgets('adds an item through the Add item screen', (tester) async {
    await pumpListScreen(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add item'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('item-name-field')),
      'Bananas',
    );
    await tester.tap(find.byKey(const ValueKey('quantity-increase')));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tester.ensureVisible(find.text('Fruits'));
    await tester.tap(find.text('Fruits'));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const ValueKey('save-item-button')));
    await tester.tap(find.byKey(const ValueKey('save-item-button')));
    await tester.pumpAndSettle();

    expect(find.text('Bananas'), findsOneWidget);
    expect(find.text('2 pcs · Fruits'), findsOneWidget);
    expect(find.text('4 item(s) left to buy'), findsOneWidget);
  });

  testWidgets('Add item screen requires a name', (tester) async {
    await pumpListScreen(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('save-item-button')));
    await tester.tap(find.byKey(const ValueKey('save-item-button')));
    await tester.pump();

    expect(find.text('Please enter an item name'), findsOneWidget);
    expect(repository.selectedList!.items, hasLength(5));
  });

  testWidgets('marking an item as bought updates the list automatically', (
    tester,
  ) async {
    await pumpListScreen(tester);

    final tomatoesToggle = find.descendant(
      of: find
          .ancestor(of: find.text('Tomatoes'), matching: find.byType(Row))
          .first,
      matching: find.byTooltip('Mark as bought'),
    );
    await tester.tap(tomatoesToggle);
    await tester.pumpAndSettle();

    expect(find.text('2 item(s) left to buy'), findsOneWidget);
    expect(find.text('3/5 bought'), findsOneWidget);
    expect(
      repository.selectedList!.boughtItems.map((item) => item.name),
      contains('Tomatoes'),
    );
  });

  testWidgets('deleting an item can be undone', (tester) async {
    await pumpListScreen(tester);

    final riceDelete = find.descendant(
      of: find
          .ancestor(of: find.text('Rice'), matching: find.byType(Row))
          .first,
      matching: find.byTooltip('Delete item'),
    );
    await tester.tap(riceDelete);
    await tester.pumpAndSettle();

    expect(find.text('Rice'), findsNothing);
    expect(find.text('Rice removed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Rice'), findsOneWidget);
  });

  testWidgets('creates a new shopping list', (tester) async {
    await pumpListScreen(tester);

    await tester.tap(find.text('New list'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Party');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Party (0)'), findsOneWidget);
    expect(find.text('Your list is empty'), findsOneWidget);
    expect(repository.lists, hasLength(2));
  });

  testWidgets('filters items by category', (tester) async {
    await pumpListScreen(tester);

    final pantryChip = find.widgetWithText(ChoiceChip, 'Pantry');
    await tester.tap(pantryChip);
    await tester.pumpAndSettle();

    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Pasta'), findsOneWidget);
    expect(find.text('Tomatoes'), findsNothing);
    expect(find.text('Milk'), findsNothing);
  });
}
