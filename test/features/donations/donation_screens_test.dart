import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/donations/data/donation_repository.dart';
import 'package:foodsaver/features/donations/domain/donation.dart';
import 'package:foodsaver/features/donations/presentation/donations_screen.dart';
import 'package:foodsaver/features/expiry/presentation/expiring_soon_screen.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/list/data/shopping_list_repository.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late FridgeRepository fridge;
  late DonationRepository repository;

  setUp(() {
    fridge = FridgeRepository(clock: () => today);
    repository = DonationRepository(fridge: fridge, seed: false);
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
  }

  testWidgets('donate a suggested food, then a charity requests it', (
    tester,
  ) async {
    await pump(tester, DonationsScreen(repository: repository));

    expect(find.text('Could be donated'), findsOneWidget);
    expect(find.text('You have no active donation.'), findsOneWidget);

    final spinachId = fridge.items.firstWhere((i) => i.name == 'Spinach').id;
    await tester.tap(find.byKey(ValueKey('donate-$spinachId')));
    await tester.pumpAndSettle();

    expect(find.text('New donation'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('publish-donation-button')));
    await tester.pumpAndSettle();

    expect(find.text('Spinach offered for donation'), findsOneWidget);
    expect(repository.activeDonations.single.foodName, 'Spinach');
    // The whole pack was donated, so it left the fridge.
    expect(fridge.items.any((i) => i.name == 'Spinach'), isFalse);

    // Beneficiary view: simulate a request.
    // "Available" is both the tab label and the status chip: tap the tab.
    await tester.tap(find.text('Available').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restos du Cœur'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('send-request-button')));
    await tester.pumpAndSettle();

    expect(find.text('Request sent by Restos du Cœur'), findsOneWidget);

    // Donor accepts the request, then marks it as collected.
    await tester.tap(find.textContaining('Spinach ·'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(repository.activeDonations.single.status, DonationStatus.reserved);

    await tester.tap(find.byKey(const ValueKey('mark-collected-button')));
    await tester.pumpAndSettle();
    expect(repository.collectedCount, 1);
  });

  testWidgets('expiring soon groups food and adds expired food to the list', (
    tester,
  ) async {
    final shopping = ShoppingListRepository(seed: false);
    fridge.addFood(
      name: 'Old cheese',
      category: fridge.categoryNamed('Dairy')!,
      quantity: 1,
      unit: 'pcs',
      expiryDate: today.subtract(const Duration(days: 1)),
    );

    await pump(
      tester,
      ExpiringSoonScreen(
        fridge: fridge,
        donations: repository,
        shopping: shopping,
      ),
    );

    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Expires today'), findsOneWidget);
    expect(find.text('Within 3 days'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Eggs'), findsNothing);

    await tester.tap(find.text('Add to list'));
    await tester.pump();

    expect(
      shopping.selectedList!.items.map((item) => item.name),
      contains('Old cheese'),
    );
  });
}
