import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/donations/data/donation_repository.dart';
import 'package:foodsaver/features/donations/domain/beneficiary.dart';
import 'package:foodsaver/features/donations/domain/donation.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/notifications/data/notification_repository.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late FridgeRepository fridge;
  late NotificationRepository notifications;
  late DonationRepository repository;

  setUp(() {
    fridge = FridgeRepository(clock: () => today);
    notifications = NotificationRepository(fridge: fridge);
    repository = DonationRepository(
      fridge: fridge,
      notifications: notifications,
      seed: false,
    );
  });

  tearDown(() => notifications.dispose());

  String foodId(String name) =>
      fridge.items.firstWhere((item) => item.name == name).id;

  Donation donateTomatoes({double quantity = 0.5}) {
    final tomatoes = fridge.itemById(foodId('Tomatoes'))!;
    return repository.createDonation(
      foodId: tomatoes.id,
      quantity: quantity,
      expiryDate: tomatoes.expiryDate,
      description: 'Ripe',
    );
  }

  test('creating a donation removes the quantity from the fridge', () {
    final donation = donateTomatoes();

    expect(donation.status, DonationStatus.available);
    expect(donation.foodName, 'Tomatoes');
    expect(fridge.itemById(foodId('Tomatoes'))!.quantity, 0.5);
    expect(repository.availableDonations, [donation]);
  });

  test('donating the whole quantity removes the food from the fridge', () {
    donateTomatoes(quantity: 1);
    expect(fridge.items.any((item) => item.name == 'Tomatoes'), isFalse);
  });

  test('rejects invalid quantities and dates after the fridge date', () {
    final tomatoes = fridge.itemById(foodId('Tomatoes'))!;
    expect(
      () => repository.createDonation(
        foodId: tomatoes.id,
        quantity: 3,
        expiryDate: tomatoes.expiryDate,
      ),
      throwsArgumentError,
    );
    expect(
      () => repository.createDonation(
        foodId: tomatoes.id,
        quantity: 0.5,
        expiryDate: tomatoes.expiryDate.add(const Duration(days: 1)),
      ),
      throwsArgumentError,
    );
  });

  test('cancelling gives the quantity back to the fridge', () {
    final donation = donateTomatoes();
    repository.cancelDonation(donation.id);

    expect(repository.donations, isEmpty);
    expect(fridge.itemById(foodId('Tomatoes'))!.quantity, 1);
  });

  test('cancelling puts the food back when it left the fridge', () {
    final donation = donateTomatoes(quantity: 1);
    repository.cancelDonation(donation.id);

    final tomatoes = fridge.items.firstWhere((i) => i.name == 'Tomatoes');
    expect(tomatoes.quantity, 1);
    expect(tomatoes.category.name, 'Vegetables');
  });

  test('request → accept → collected, other requests are refused', () {
    final donation = donateTomatoes();
    final first = repository.requestDonation(
      donation.id,
      sampleBeneficiaries[0],
      message: 'Tonight?',
    );
    final second = repository.requestDonation(
      donation.id,
      sampleBeneficiaries[2],
    );

    expect(repository.pendingRequestCount, 2);
    expect(notifications.donationNotifications, hasLength(2));

    repository.acceptRequest(donation.id, second.id);
    var updated = repository.donationById(donation.id)!;
    expect(updated.status, DonationStatus.reserved);
    expect(updated.acceptedRequest!.beneficiary, sampleBeneficiaries[2]);
    expect(
      updated.requests.firstWhere((r) => r.id == first.id).status,
      RequestStatus.refused,
    );
    expect(repository.availableDonations, isEmpty);

    repository.markCollected(donation.id);
    updated = repository.donationById(donation.id)!;
    expect(updated.status, DonationStatus.collected);
    expect(updated.collectedAt, today);
    expect(repository.collectedCount, 1);
  });

  test('refusing a request keeps the donation available', () {
    final donation = donateTomatoes();
    final request = repository.requestDonation(
      donation.id,
      sampleBeneficiaries[1],
    );
    repository.refuseRequest(donation.id, request.id);

    final updated = repository.donationById(donation.id)!;
    expect(updated.status, DonationStatus.available);
    expect(updated.pendingRequests, isEmpty);
  });

  test('a beneficiary cannot ask twice, nor ask a reserved donation', () {
    final donation = donateTomatoes();
    final request = repository.requestDonation(
      donation.id,
      sampleBeneficiaries[0],
    );
    expect(
      () => repository.requestDonation(donation.id, sampleBeneficiaries[0]),
      throwsStateError,
    );

    repository.acceptRequest(donation.id, request.id);
    expect(
      () => repository.requestDonation(donation.id, sampleBeneficiaries[3]),
      throwsStateError,
    );
    expect(() => repository.cancelDonation(donation.id), throwsStateError);
  });

  test('suggested foods are the ones expiring within 7 days', () {
    expect(repository.suggestedFoods.map((f) => f.name), contains('Lemon'));
    expect(
      repository.suggestedFoods.map((f) => f.name),
      isNot(contains('Eggs')),
    );
  });
}
