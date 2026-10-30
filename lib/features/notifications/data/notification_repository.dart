import 'package:flutter/material.dart';

import '../../../core/firebase/firebase_setup.dart';
import '../../expiry/domain/expiry_alerts.dart';
import '../../fridge/data/fridge_repository.dart';
import '../domain/app_notification.dart';
import 'notification_firestore.dart';

/// Sends a phone notification. Set by `main.dart` to
/// [NotificationService.showNow]; left empty in tests.
typedef PushHandler = void Function(String title, String body);

/// In-app notifications.
///
/// Expiry alerts are not stored: they are recomputed from the fridge every
/// time, so they always match the fridge data. Only donation events and the
/// "read" state are kept here (and saved in Firestore when [remote] is set).
class NotificationRepository extends ChangeNotifier {
  NotificationRepository({
    FridgeRepository? fridge,
    this.pushHandler,
    this.remote,
  }) : _fridge = fridge ?? FridgeRepository.instance {
    // Expiry alerts change whenever the fridge changes.
    _fridge.addListener(notifyListeners);
    if (remote != null) {
      _loadRemote();
    }
  }

  static final NotificationRepository instance = NotificationRepository(
    remote: FirebaseSetup.isReady ? NotificationFirestore() : null,
  );

  final FridgeRepository _fridge;

  /// Firestore storage; null in tests or when Firebase is not configured.
  final NotificationFirestore? remote;
  PushHandler? pushHandler;

  final List<AppNotification> _events = [];
  final Set<String> _readIds = {};
  int _idCounter = 0;

  DateTime get now => _fridge.now;

  /// Current expiry alerts, most urgent first.
  List<AppNotification> get expiryNotifications {
    return expiryAlerts(_fridge.items, now).map((alert) {
      return AppNotification(
        id: alert.id,
        type: AppNotificationType.expiry,
        title: alert.title,
        body: alert.message,
        createdAt: now,
        isRead: _readIds.contains(alert.id),
        foodId: alert.item.id,
        level: alert.level,
      );
    }).toList();
  }

  /// Donation events, newest first.
  List<AppNotification> get donationNotifications => _events
      .map((event) => event.copyWith(isRead: _readIds.contains(event.id)))
      .toList();

  List<AppNotification> get all => [
    ...donationNotifications,
    ...expiryNotifications,
  ];

  int get unreadCount => all.where((n) => !n.isRead).length;

  void markRead(String id) {
    if (_readIds.add(id)) {
      notifyListeners();
      _sync(() => remote!.markRead([id]));
    }
  }

  void markAllRead() {
    final ids = all.map((n) => n.id).toList();
    _readIds.addAll(ids);
    notifyListeners();
    _sync(() => remote!.markRead(ids));
  }

  /// Adds a donation event (e.g. a new request) and sends it to the phone.
  void addDonationEvent({
    required String title,
    required String body,
    required String donationId,
  }) {
    final event = AppNotification(
      id: 'donation-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}',
      type: AppNotificationType.donation,
      title: title,
      body: body,
      createdAt: now,
      donationId: donationId,
    );
    _events.insert(0, event);
    pushHandler?.call(title, body);
    notifyListeners();
    _sync(() => remote!.saveEvent(event));
  }

  Future<void> _loadRemote() async {
    try {
      final (events, readIds) = await remote!.load();
      for (final event in events) {
        if (!_events.any((existing) => existing.id == event.id)) {
          _events.add(event);
        }
      }
      _events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _readIds.addAll(readIds);
      notifyListeners();
    } catch (error) {
      debugPrint('Could not load notifications: $error');
    }
  }

  /// Runs a Firestore write without blocking the screen.
  void _sync(Future<void> Function() write) {
    if (remote == null) {
      return;
    }
    write().catchError(
      (Object error) => debugPrint('Could not save notification: $error'),
    );
  }

  @override
  void dispose() {
    _fridge.removeListener(notifyListeners);
    super.dispose();
  }
}
