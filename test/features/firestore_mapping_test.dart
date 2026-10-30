import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/donations/data/donation_firestore.dart';
import 'package:foodsaver/features/donations/domain/beneficiary.dart';
import 'package:foodsaver/features/donations/domain/donation.dart';
import 'package:foodsaver/features/fridge/domain/food_category.dart';
import 'package:foodsaver/features/list/data/shopping_list_firestore.dart';
import 'package:foodsaver/features/list/domain/shopping_category.dart';
import 'package:foodsaver/features/list/domain/shopping_item.dart';
import 'package:foodsaver/features/list/domain/shopping_list.dart';
import 'package:foodsaver/features/notifications/data/notification_firestore.dart';
import 'package:foodsaver/features/notifications/domain/app_notification.dart';

// Checks that what is written to Firestore can be read back unchanged.
void main() {
  final date = DateTime(2026, 10, 30, 18, 15);

  test('shopping list round trip', () {
    final dairy = defaultShoppingCategories.firstWhere(
      (c) => c.name == 'Dairy',
    );
    final list = ShoppingList(
      id: 'list-1',
      name: 'Weekly',
      createdAt: date,
      items: [
        ShoppingItem(
          id: 'item-1',
          name: 'Milk',
          category: dairy,
          quantity: 2,
          unit: 'L',
          note: 'skimmed',
          isBought: true,
          boughtAt: date,
          createdAt: date,
        ),
      ],
    );

    final map = {...shoppingListToMap(list), 'id': list.id};
    expect(map['items'][0]['category'], 'Dairy');

    final back = shoppingListFromMap(
      map,
      (name) => defaultShoppingCategories.firstWhere((c) => c.name == name),
    );
    final item = back.items.single;
    expect(back.name, 'Weekly');
    expect(item.name, 'Milk');
    expect(item.category, dairy);
    expect(item.quantity, 2);
    expect(item.isBought, isTrue);
    expect(item.boughtAt, date);
  });

  test('donation round trip with requests', () {
    final donation = Donation(
      id: 'don-1',
      donorId: 'demo-user',
      foodId: 'food-1',
      foodName: 'Rice',
      category: otherFoodCategory,
      quantity: 1.5,
      unit: 'kg',
      expiryDate: date,
      createdAt: date,
      description: 'Unopened',
      status: DonationStatus.reserved,
      requests: [
        DonationRequest(
          id: 'req-1',
          beneficiary: sampleBeneficiaries[2],
          createdAt: date,
          message: 'Tonight',
          status: RequestStatus.accepted,
        ),
      ],
    );

    final back = donationFromMap({
      ...donationToMap(donation),
      'id': donation.id,
    }, (name) => otherFoodCategory);
    expect(back.donorId, 'demo-user');
    expect(back.quantity, 1.5);
    expect(back.status, DonationStatus.reserved);
    expect(back.expiryDate, date);
    final request = back.requests.single;
    expect(request.status, RequestStatus.accepted);
    expect(request.beneficiary.name, sampleBeneficiaries[2].name);
    expect(request.beneficiary.type, BeneficiaryType.restaurant);
  });

  test('notification round trip', () {
    final event = AppNotification(
      id: 'donation-1',
      type: AppNotificationType.donation,
      title: 'New request',
      body: 'A charity asked',
      createdAt: date,
      donationId: 'don-1',
    );
    final back = notificationFromMap({
      ...notificationToMap(event),
      'id': event.id,
    });
    expect(back.title, 'New request');
    expect(back.donationId, 'don-1');
    expect(back.createdAt, date);
  });
}
