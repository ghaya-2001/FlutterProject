import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/core/session/current_user.dart';
import 'package:foodsaver/features/auth/data/auth_repository.dart';
import 'package:foodsaver/features/auth/data/session_binder.dart';
import 'package:foodsaver/features/donations/data/donation_repository.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/list/data/shopping_list_repository.dart';
import 'package:foodsaver/features/notifications/data/notification_repository.dart';
import 'package:foodsaver/features/profile/data/user_profile_repository.dart';
import 'package:foodsaver/features/profile/domain/user_role.dart';

void main() {
  late AuthRepository auth;
  late UserProfileRepository profiles;
  late FridgeRepository fridge;
  late ShoppingListRepository shopping;
  late DonationRepository donations;
  late SessionBinder binder;

  setUp(() {
    final now = DateTime(2026, 11, 1);
    auth = AuthRepository();
    profiles = UserProfileRepository(auth: auth, clock: () => now);
    fridge = FridgeRepository(clock: () => now);
    shopping = ShoppingListRepository();
    final notifications = NotificationRepository(fridge: fridge);
    donations = DonationRepository(
      fridge: fridge,
      notifications: notifications,
    );
    binder = SessionBinder(
      auth: auth,
      profiles: profiles,
      fridge: fridge,
      shopping: shopping,
      notifications: notifications,
      donations: donations,
    );
  });

  tearDown(() {
    binder.dispose();
    CurrentUser.bind(null);
  });

  Future<void> signUp(String email, {UserRole role = UserRole.user}) async {
    if (role != UserRole.user) {
      profiles.prepareSignUp(role: role, businessName: 'Biz');
    }
    await auth.signUp(displayName: 'Maya', email: email, password: 'secret12');
    await Future<void>.delayed(Duration.zero); // let the binder connect
  }

  test('uses the demo user until someone signs in', () {
    expect(CurrentUser.isBound, isFalse);
    expect(CurrentUser.uid, CurrentUser.demoUserId);
    expect(fridge.items, isNotEmpty); // untouched demo data
  });

  test('points the data at the signed-in account', () async {
    await signUp('a@example.com');
    expect(CurrentUser.uid, auth.currentUser!.uid);
    expect(donations.userId, auth.currentUser!.uid);
  });

  test('logout empties every repository', () async {
    await signUp('a@example.com');
    expect(fridge.items, isNotEmpty);
    expect(shopping.lists, isNotEmpty);

    await auth.signOut();
    expect(CurrentUser.isBound, isFalse);
    expect(fridge.items, isEmpty);
    expect(shopping.lists, isEmpty);
    expect(donations.donations, isEmpty);
  });

  test('a second account does not keep the first one\'s changes', () async {
    await signUp('a@example.com');
    final firstFood = fridge.items.first;
    fridge.throwAway(firstFood.id);
    expect(fridge.items.any((item) => item.id == firstFood.id), isFalse);

    final firstUid = CurrentUser.uid;
    await auth.signOut();
    await signUp('b@example.com');
    expect(CurrentUser.uid, isNot(firstUid));
    // Fresh data for the new account, loaded again from scratch.
    expect(fridge.items, isNotEmpty);
  });

  test('restaurants and admins do not load the fridge or the lists', () async {
    await signUp('r@example.com', role: UserRole.restaurant);
    expect(fridge.items, isEmpty);
    expect(shopping.lists, isEmpty);
  });
}
