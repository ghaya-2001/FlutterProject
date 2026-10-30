import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../expiry/domain/expiry_alerts.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../fridge/domain/food_item.dart';

/// Phone notifications (local notifications, no server needed).
///
/// Schedules the 7-day, 3-day and same-day expiry alerts for every fridge
/// food, and re-schedules them whenever the fridge changes. Only Android and
/// iOS are supported; on other platforms every method does nothing.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _expiryChannel = AndroidNotificationDetails(
    'expiry_alerts',
    'Expiry alerts',
    channelDescription: 'Reminders before your food expires',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _donationChannel = AndroidNotificationDetails(
    'donations',
    'Donations',
    channelDescription: 'Requests for your food donations',
    importance: Importance.high,
    priority: Priority.high,
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void> _queue = Future.value();
  int _nextShowId = 100000;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init(FridgeRepository fridge) async {
    if (!isSupported || _ready) {
      return;
    }
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (error) {
      debugPrint('Notifications unavailable: $error');
      return;
    }

    fridge.addListener(() => _scheduleQueued(fridge));
    _scheduleQueued(fridge);
  }

  /// Shows a notification right away (used for donation requests).
  void showNow(String title, String body) {
    if (!_ready) {
      return;
    }
    _plugin.show(
      id: _nextShowId++,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: _donationChannel,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Runs one re-scheduling at a time, in order.
  void _scheduleQueued(FridgeRepository fridge) {
    _queue = _queue
        .then((_) => _scheduleExpiryAlerts(fridge))
        .catchError(
          (Object error) => debugPrint('Could not schedule alerts: $error'),
        );
  }

  Future<void> _scheduleExpiryAlerts(FridgeRepository fridge) async {
    // Simplest reliable approach: clear everything and schedule again from
    // the current fridge content.
    await _plugin.cancelAllPendingNotifications();
    var id = 0;
    for (final item in fridge.items) {
      for (final moment in alertMomentsFor(item, fridge.now)) {
        await _plugin.zonedSchedule(
          id: id++,
          title: _titleFor(item, moment),
          body: 'Open Food Saver to use it, or donate it before it is lost.',
          // The moment is converted to an absolute instant, so the phone's
          // own time zone is respected without extra packages.
          scheduledDate: tz.TZDateTime.from(moment, tz.UTC),
          notificationDetails: const NotificationDetails(
            android: _expiryChannel,
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  String _titleFor(FoodItem item, DateTime moment) {
    // UTC calendar dates, so daylight saving changes don't matter.
    final expiry = DateTime.utc(
      item.expiryDate.year,
      item.expiryDate.month,
      item.expiryDate.day,
    );
    final day = DateTime.utc(moment.year, moment.month, moment.day);
    final days = expiry.difference(day).inDays;
    if (days <= 0) {
      return expiryAlertTitle(item.name, ExpiryAlertLevel.today);
    }
    if (days <= priorityThresholdDays) {
      return expiryAlertTitle(item.name, ExpiryAlertLevel.threeDays);
    }
    return expiryAlertTitle(item.name, ExpiryAlertLevel.sevenDays);
  }
}
