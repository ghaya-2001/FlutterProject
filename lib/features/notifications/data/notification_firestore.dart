import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firebase_setup.dart';
import '../domain/app_notification.dart';

/// Reads and writes the user's notifications in Firestore.
///
/// Structure:
/// ```
/// users/{userId}                      readNotificationIds: [...]
/// users/{userId}/notifications/{id}   type, title, body, donationId, createdAt
/// ```
/// Expiry alerts are not stored: they are always recomputed from the fridge.
/// Only donation events and the "read" state are saved.
class NotificationFirestore {
  NotificationFirestore({
    FirebaseFirestore? firestore,
    this.userId = currentUserId,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final String userId;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(userId);

  CollectionReference<Map<String, dynamic>> get _events =>
      _user.collection('notifications');

  /// Donation events (newest first) and the ids already read.
  Future<(List<AppNotification>, Set<String>)> load() async {
    final user = await _user.get();
    final events = await _events.orderBy('createdAt', descending: true).get();
    return (
      [
        for (final doc in events.docs)
          notificationFromMap({...doc.data(), 'id': doc.id}),
      ],
      Set<String>.from(
        user.data()?['readNotificationIds'] as List? ?? const [],
      ),
    );
  }

  Future<void> saveEvent(AppNotification event) =>
      _events.doc(event.id).set(notificationToMap(event));

  Future<void> markRead(Iterable<String> ids) {
    return _user.set({
      'readNotificationIds': FieldValue.arrayUnion(ids.toList()),
    }, SetOptions(merge: true));
  }
}

Map<String, dynamic> notificationToMap(AppNotification notification) {
  return {
    'type': notification.type.name,
    'title': notification.title,
    'body': notification.body,
    'donationId': notification.donationId,
    'createdAt': Timestamp.fromDate(notification.createdAt),
  };
}

AppNotification notificationFromMap(Map<String, dynamic> map) {
  final createdAt = map['createdAt'];
  return AppNotification(
    id: map['id'] as String,
    type: map['type'] == AppNotificationType.expiry.name
        ? AppNotificationType.expiry
        : AppNotificationType.donation,
    title: map['title'] as String? ?? '',
    body: map['body'] as String? ?? '',
    donationId: map['donationId'] as String?,
    createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
  );
}
