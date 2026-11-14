import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/auth/data/auth_repository.dart';
import 'package:foodsaver/features/donations/data/donation_repository.dart';
import 'package:foodsaver/features/donations/domain/beneficiary.dart';
import 'package:foodsaver/features/donations/domain/donation.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/profile/data/user_profile_repository.dart';
import 'package:foodsaver/features/profile/domain/user_role.dart';
import 'package:foodsaver/features/roles/presentation/request_history_tab.dart';
import 'package:foodsaver/features/roles/presentation/role_home.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late FridgeRepository fridge;
  late DonationRepository donations;
  late AuthRepository auth;
  late UserProfileRepository profiles;
  late Donation tomatoes;
  late Donation milk;
  late Beneficiary me;

  setUp(() async {
    fridge = FridgeRepository(clock: () => today);
    donations = DonationRepository(
      fridge: fridge,
      userId: 'donor-1',
      seed: false,
    );
    donate(String name) {
      final food = fridge.items.firstWhere((item) => item.name == name);
      return donations.createDonation(
        foodId: food.id,
        quantity: 0.5,
        expiryDate: food.expiryDate,
      );
    }

    tomatoes = donate('Tomatoes');
    milk = donate('Milk');

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
    me = Beneficiary(
      id: profiles.profile!.uid,
      name: 'Le Jardin',
      type: BeneficiaryType.restaurant,
      area: '',
    );
  });

  Future<void> pump(WidgetTester tester, {required bool forRestaurant}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequestHistoryTab(
              title: 'History',
              emptyMessage: 'Nothing yet',
              forRestaurant: forRestaurant,
              donations: donations,
              profiles: profiles,
            ),
          ),
        ),
      );

  test('requestRecords filters by requester and by answer', () {
    final mine = donations.requestDonation(tomatoes.id, me);
    final other = donations.requestDonation(milk.id, sampleBeneficiaries[0]);
    donations.refuseRequest(milk.id, other.id);

    expect(donations.requestRecords().length, 2);
    expect(
      donations.requestRecords(beneficiaryId: me.id).single.request.id,
      mine.id,
    );
    expect(
      donations.requestRecords(includePending: false).single.request.status,
      RequestStatus.refused,
    );
  });

  testWidgets('a restaurant sees only its own requests, pending included', (
    tester,
  ) async {
    final mine = donations.requestDonation(tomatoes.id, me);
    final other = donations.requestDonation(milk.id, sampleBeneficiaries[0]);
    await pump(tester, forRestaurant: true);

    expect(find.byKey(ValueKey('history-${mine.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('history-${other.id}')), findsNothing);
    expect(find.text('Pending'), findsWidgets);
  });

  testWidgets('a restaurant can filter its history by answer', (tester) async {
    final first = donations.requestDonation(tomatoes.id, me);
    final second = donations.requestDonation(milk.id, me);
    donations.refuseRequest(milk.id, second.id);
    await pump(tester, forRestaurant: true);

    await tester.tap(find.byKey(const ValueKey('history-filter-refused')));
    await tester.pump();

    expect(find.byKey(ValueKey('history-${first.id}')), findsNothing);
    expect(find.byKey(ValueKey('history-${second.id}')), findsOneWidget);
  });

  testWidgets('the admin sees answered requests with who asked', (
    tester,
  ) async {
    final waiting = donations.requestDonation(tomatoes.id, me);
    final answered = donations.requestDonation(milk.id, sampleBeneficiaries[0]);
    donations.acceptRequest(milk.id, answered.id);
    await pump(tester, forRestaurant: false);

    expect(find.byKey(ValueKey('history-${answered.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('history-${waiting.id}')), findsNothing);
    expect(
      find.textContaining('Requested by ${sampleBeneficiaries[0].name}'),
      findsOneWidget,
    );
    expect(find.text('Accepted'), findsWidgets);
  });

  testWidgets('shows the empty message when there is no request', (
    tester,
  ) async {
    await pump(tester, forRestaurant: true);
    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgets('a restaurant has a Stock tab without a Donate button', (
    tester,
  ) async {
    final stock = FridgeRepository(clock: () => today);
    await tester.pumpWidget(
      MaterialApp(
        home: RoleHome(
          profiles: profiles,
          auth: auth,
          donations: donations,
          fridge: stock,
        ),
      ),
    );

    await tester.tap(find.text('Stock'));
    await tester.pumpAndSettle();
    expect(find.text('My stock'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('My requests'), findsOneWidget);
  });
}
