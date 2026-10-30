import '../../expiry/domain/expiry_alerts.dart';

enum AppNotificationType { expiry, donation }

/// One row of the Notifications screen.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.foodId,
    this.donationId,
    this.level,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Set for expiry alerts: the fridge food concerned.
  final String? foodId;

  /// Set for donation events: the donation concerned.
  final String? donationId;

  /// Set for expiry alerts.
  final ExpiryAlertLevel? level;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      foodId: foodId,
      donationId: donationId,
      level: level,
    );
  }
}
