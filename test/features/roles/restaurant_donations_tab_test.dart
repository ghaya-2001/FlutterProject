import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/auth/data/auth_repository.dart';
import 'package:foodsaver/features/donations/data/donation_repository.dart';
import 'package:foodsaver/features/donations/domain/donation.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/profile/data/user_profile_repository.dart';
import 'package:foodsaver/features/profile/domain/user_role.dart';
import 'package:foodsaver/features/roles/presentation/role_home.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late DonationRepository donations;
  late Donation donation;
  late AuthRepository auth;
  late UserProfileRepository profiles;

  setUp(() async {
    // A donor published a donation; the restaurant signs in afterwards.
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

    auth = AuthRepository();
    profiles = UserProfileRepository(auth: auth);
    profiles.prepareSignUp(
      role: UserRole.restaurant,
      businessName: 'Le Jardin',
    );
    await auth.signUp(
      displayName: 'Sam',
      email: 'sam@example.com',
      password: 'secret12',
    );
  });

  Future<void> pumpRestaurant(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: RoleHome(profiles: profiles, auth: auth, donations: donations),
    ),
  );

  testWidgets('a restaurant sees a donation published by another user', (
    tester,
  ) async {
    await pumpRestaurant(tester);

    expect(
      find.byKey(ValueKey('restaurant-donation-${donation.id}')),
      findsOneWidget,
    );
    expect(find.textContaining('Tomatoes'), findsOneWidget);
  });

  testWidgets('a restaurant can request a donation once', (tester) async {
    await pumpRestaurant(tester);

    await tester.tap(find.byKey(ValueKey('request-${donation.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('send-request-button')));
    await tester.pumpAndSettle();

    final request = donations.donationById(donation.id)!.requests.single;
    expect(request.beneficiary.name, 'Le Jardin');
    expect(request.beneficiary.id, profiles.profile!.uid);
    expect(find.text('Requested'), findsOneWidget);
    expect(find.byKey(ValueKey('request-${donation.id}')), findsNothing);
  });
}
