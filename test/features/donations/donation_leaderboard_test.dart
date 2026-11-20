import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/donations/data/donation_repository.dart';
import 'package:foodsaver/features/donations/domain/beneficiary.dart';
import 'package:foodsaver/features/donations/domain/donation.dart';
import 'package:foodsaver/features/donations/domain/donation_leaderboard.dart';
import 'package:foodsaver/features/donations/presentation/donation_leaderboard_screen.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/fridge/domain/food_category.dart';

void main() {
  final today = DateTime(2026, 11, 20, 10);
  var counter = 0;

  Donation donation(
    String name,
    double quantity, {
    String unit = 'kg',
    DonationStatus status = DonationStatus.collected,
  }) {
    counter++;
    return Donation(
      id: 'd$counter',
      donorId: 'user-$counter',
      foodId: 'food-$counter',
      foodName: name,
      category: otherFoodCategory,
      quantity: quantity,
      unit: unit,
      expiryDate: today,
      createdAt: today.add(Duration(minutes: counter)),
      status: status,
    );
  }

  group('donationLeaderboard', () {
    test('counts only completed (collected) donations', () {
      final entries = donationLeaderboard([
        donation('Rice', 1),
        donation('Rice', 2, status: DonationStatus.available),
        donation('Rice', 3, status: DonationStatus.reserved),
      ]);
      expect(entries.single.timesDonated, 1);
      expect(entries.single.totalQuantity, 1);
    });

    test('ranks by number of donations, then by quantity, then by name', () {
      final entries = donationLeaderboard([
        donation('Bread', 2, unit: 'pcs'),
        donation('Rice', 1),
        donation('Rice', 1.5),
        donation('Milk', 3, unit: 'L'),
        donation('Apples', 3),
      ]);
      expect(entries.map((e) => e.foodName), [
        'Rice',
        'Apples',
        'Milk',
        'Bread',
      ]);
      expect(entries.first.timesDonated, 2);
      expect(entries.first.totalQuantity, 2.5);
    });

    test('groups names regardless of case and spaces, keeps units apart', () {
      final entries = donationLeaderboard([
        donation('rice', 1),
        donation(' Rice ', 2),
        donation('Rice', 1, unit: 'pack'),
      ]);
      expect(entries, hasLength(2));
      final kg = entries.firstWhere((e) => e.unit == 'kg');
      expect(kg.timesDonated, 2);
      expect(kg.totalQuantity, 3);
      expect(kg.foodName, 'Rice');
    });

    test('no completed donation gives an empty leaderboard', () {
      expect(
        donationLeaderboard([
          donation('Rice', 1, status: DonationStatus.available),
        ]),
        isEmpty,
      );
    });
  });

  group('screen', () {
    late FridgeRepository fridge;
    late DonationRepository repository;

    setUp(() {
      fridge = FridgeRepository(clock: () => today);
      repository = DonationRepository(fridge: fridge, seed: false);
    });

    /// Donates [quantity] of a fridge food and takes it through the whole
    /// flow until it is collected.
    void donateAndCollect(String foodName, double quantity) {
      final food = fridge.items.firstWhere((item) => item.name == foodName);
      final created = repository.createDonation(
        foodId: food.id,
        quantity: quantity,
        expiryDate: food.expiryDate,
      );
      final request = repository.requestDonation(
        created.id,
        sampleBeneficiaries.first,
      );
      repository.acceptRequest(created.id, request.id);
      repository.markCollected(created.id);
    }

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: DonationLeaderboardScreen(repository: repository)),
      );
    }

    testWidgets('shows the ranked foods with quantity and count', (
      tester,
    ) async {
      donateAndCollect('Eggs', 2);
      donateAndCollect('Eggs', 3);
      donateAndCollect('Milk', 0.5);
      // Published but not collected: not counted.
      final lemon = fridge.items.firstWhere((item) => item.name == 'Lemon');
      repository.createDonation(
        foodId: lemon.id,
        quantity: 1,
        expiryDate: lemon.expiryDate,
      );

      await pump(tester);

      expect(find.text('3 completed donations'), findsOneWidget);
      expect(
        find.text('2 different foods shared with the community'),
        findsOneWidget,
      );
      final first = find.byKey(const ValueKey('leaderboard-row-1'));
      expect(
        find.descendant(of: first, matching: find.text('Eggs')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: first, matching: find.text('Donated 2 times')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: first, matching: find.text('5 pcs')),
        findsOneWidget,
      );
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Lemon'), findsNothing);
    });

    testWidgets('explains when nothing has been collected yet', (tester) async {
      await pump(tester);
      expect(find.text('0 completed donations'), findsOneWidget);
      expect(find.textContaining('No completed donation yet'), findsOneWidget);
    });
  });
}
