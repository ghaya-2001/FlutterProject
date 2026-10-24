import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/fridge/presentation/fridge_screen.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late FridgeRepository repository;

  // Seeded fridge on [today]:
  //   Use first   -> Yogurt (today), Chicken breast (1), Spinach (2), Tomatoes (3)
  //   Fresh items -> Milk (5), Lemon (7), Eggs (14)
  setUp(() {
    repository = FridgeRepository(clock: () => today);
  });

  Future<void> pumpFridge(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: FridgeScreen(repository: repository)),
    );
  }

  testWidgets('shows stock, total and priority foods sorted by expiry', (
    tester,
  ) async {
    await pumpFridge(tester);

    expect(find.text('My fridge'), findsOneWidget);
    expect(find.text('7 ingredients ready to use'), findsOneWidget);
    expect(find.text('7 in stock'), findsOneWidget);
    expect(find.text('4 to use first'), findsOneWidget);
    expect(find.text('Use first'), findsOneWidget);
    expect(find.text('Fresh items'), findsOneWidget);

    final yogurtY = tester.getTopLeft(find.text('Yogurt')).dy;
    final chickenY = tester.getTopLeft(find.text('Chicken breast')).dy;
    final spinachY = tester.getTopLeft(find.text('Spinach')).dy;
    final milkY = tester.getTopLeft(find.text('Milk')).dy;
    expect(yogurtY, lessThan(chickenY));
    expect(chickenY, lessThan(spinachY));
    expect(spinachY, lessThan(milkY));
  });

  testWidgets('searches food by name', (tester) async {
    await pumpFridge(tester);

    await tester.enterText(
      find.byKey(const ValueKey('fridge-search-field')),
      'mil',
    );
    await tester.pump();

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Spinach'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('fridge-search-field')),
      'pizza',
    );
    await tester.pump();
    expect(find.text('No food found'), findsOneWidget);
  });

  testWidgets('filters food by category', (tester) async {
    await pumpFridge(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Dairy'));
    await tester.pump();

    expect(find.text('Yogurt'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Eggs'), findsOneWidget);
    expect(find.text('Spinach'), findsNothing);
    expect(find.text('Lemon'), findsNothing);
  });

  testWidgets('adds a food with its expiry date', (tester) async {
    await pumpFridge(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add food'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('food-name-field')),
      'Cheese',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Dairy'));
    await tester.tap(find.byKey(const ValueKey('quantity-increase')));
    await tester.tap(find.widgetWithText(ChoiceChip, '+1 week'));
    await tester.pump();
    expect(find.text('31 Oct 2026'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('save-food-button')));
    await tester.tap(find.byKey(const ValueKey('save-food-button')));
    await tester.pumpAndSettle();

    expect(find.text('Cheese'), findsOneWidget);
    expect(find.text('2 pcs · Dairy'), findsOneWidget);
    expect(find.text('8 ingredients ready to use'), findsOneWidget);
    expect(find.text('Cheese added to your fridge'), findsOneWidget);
  });

  testWidgets('add food requires a name and an expiry date', (tester) async {
    await pumpFridge(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('save-food-button')));
    await tester.tap(find.byKey(const ValueKey('save-food-button')));
    await tester.pump();

    expect(find.text('Please enter a food name'), findsOneWidget);
    expect(find.text('Please choose an expiry date'), findsOneWidget);
    expect(repository.totalCount, 7);
  });

  testWidgets('food details, consumption updates the stock', (tester) async {
    await pumpFridge(tester);

    await tester.tap(find.text('Eggs'));
    await tester.pumpAndSettle();

    expect(find.text('Food details'), findsOneWidget);
    expect(find.text('Quantity available'), findsOneWidget);
    expect(find.text('7 Nov 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('consume-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('consume-increase')));
    await tester.pump();
    await tester.tap(find.text('Consume').last);
    await tester.pumpAndSettle();

    expect(repository.query(search: 'Eggs').single.quantity, 4);
    expect(find.text('2 pcs consumed · 4 pcs left'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('consume-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finished it all'));
    await tester.pump();
    await tester.tap(find.text('Consume').last);
    await tester.pumpAndSettle();

    expect(find.text('My fridge'), findsOneWidget);
    expect(find.text('Eggs'), findsNothing);
    expect(find.text('Eggs finished and removed'), findsOneWidget);
  });

  testWidgets('edits a food from its details', (tester) async {
    await pumpFridge(tester);

    await tester.tap(find.text('Lemon'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-food-button')));
    await tester.pumpAndSettle();

    expect(find.text('Edit food'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('food-name-field')),
      'Lime',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-food-button')));
    await tester.tap(find.byKey(const ValueKey('save-food-button')));
    await tester.pumpAndSettle();

    expect(find.text('Food details'), findsOneWidget);
    expect(find.text('Lime'), findsOneWidget);
  });

  testWidgets('deletes a food from its details', (tester) async {
    await pumpFridge(tester);

    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-food-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, delete'));
    await tester.pumpAndSettle();

    expect(find.text('My fridge'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);
    expect(repository.totalCount, 6);
  });

  testWidgets('swipe to delete can be undone', (tester) async {
    await pumpFridge(tester);

    await tester.drag(find.text('Lemon'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Lemon'), findsNothing);
    expect(find.text('Lemon removed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Lemon'), findsOneWidget);
  });
}
