import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/notifications/data/notification_repository.dart';
import 'package:foodsaver/features/notifications/domain/app_notification.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late FridgeRepository fridge;
  late NotificationRepository repository;

  setUp(() {
    fridge = FridgeRepository(clock: () => today);
    repository = NotificationRepository(fridge: fridge);
  });

  tearDown(() => repository.dispose());

  test('expiry alerts come from the fridge data', () {
    // 6 seeded foods expire within 7 days (Eggs expire in 14).
    expect(repository.expiryNotifications, hasLength(6));
    expect(repository.expiryNotifications.first.title, 'Yogurt expires today');

    final yogurt = fridge.items.firstWhere((item) => item.name == 'Yogurt');
    fridge.deleteFood(yogurt.id);
    expect(repository.expiryNotifications, hasLength(5));
  });

  test('read state and unread counter', () {
    expect(repository.unreadCount, 6);
    repository.markRead(repository.expiryNotifications.first.id);
    expect(repository.unreadCount, 5);
    repository.markAllRead();
    expect(repository.unreadCount, 0);
  });

  test('donation events are stored and pushed to the phone', () {
    final pushed = <String>[];
    repository.pushHandler = (title, body) => pushed.add(title);

    repository.addDonationEvent(
      title: 'New request',
      body: 'A charity asked',
      donationId: 'd1',
    );

    expect(pushed, ['New request']);
    expect(
      repository.donationNotifications.single.type,
      AppNotificationType.donation,
    );
    expect(repository.all.first.donationId, 'd1');
  });
}
