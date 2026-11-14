import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/donations/data/donation_repository.dart';
import 'package:foodsaver/features/donations/domain/beneficiary.dart';
import 'package:foodsaver/features/donations/domain/donation.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/roles/presentation/admin_requests_tab.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late DonationRepository donations;
  late Donation donation;

  setUp(() {
    final fridge = FridgeRepository(clock: () => today);
    donations = DonationRepository(
      fridge: fridge,
      userId: 'donor-1',
      seed: false,
    );
    final tomatoes = fridge.items.firstWhere((item) => item.name == 'Tomatoes');
    donation = donations.createDonation(
      foodId: tomatoes.id,
      quantity: 0.5,
      expiryDate: tomatoes.expiryDate,
    );
  });

  Future<void> pumpAdmin(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminRequestsTab(
          title: 'Pending requests',
          emptyMessage: 'Nothing yet',
          donations: donations,
        ),
      ),
    ),
  );

  DonationRequest ask() => donations.requestDonation(
    donation.id,
    sampleBeneficiaries[0],
    message: 'Tonight?',
  );

  testWidgets('shows a message when no request is waiting', (tester) async {
    await pumpAdmin(tester);
    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgets('lists a pending request from a restaurant', (tester) async {
    final request = ask();
    await pumpAdmin(tester);

    expect(
      find.byKey(ValueKey('admin-request-${request.id}')),
      findsOneWidget,
    );
    expect(find.textContaining('Tonight?'), findsOneWidget);
  });

  testWidgets('accepting a request reserves the donation', (tester) async {
    final request = ask();
    await pumpAdmin(tester);

    await tester.tap(find.byKey(ValueKey('accept-${request.id}')));
    await tester.pump();

    expect(
      donations.donationById(donation.id)!.status,
      DonationStatus.reserved,
    );
    expect(find.byKey(ValueKey('admin-request-${request.id}')), findsNothing);
  });

  testWidgets('refusing a request keeps the donation available', (
    tester,
  ) async {
    final request = ask();
    await pumpAdmin(tester);

    await tester.tap(find.byKey(ValueKey('refuse-${request.id}')));
    await tester.pump();

    final updated = donations.donationById(donation.id)!;
    expect(updated.status, DonationStatus.available);
    expect(updated.requests.single.status, RequestStatus.refused);
    expect(find.text('Nothing yet'), findsOneWidget);
  });
}
