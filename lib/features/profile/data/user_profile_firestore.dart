import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/user_profile.dart';
import '../domain/user_role.dart';
import '../domain/user_settings.dart';

/// Reads and writes the user's profile in Firestore.
///
/// Structure:
/// ```
/// users/{uid}   displayName, email, photo, createdAt, role, businessName,
///               settings: { notificationsEnabled }
/// ```
/// The same document also holds other modules' fields (custom categories,
/// selected shopping list, read notifications), so every write is a merge.
///
/// Unlike the other modules, the uid is passed to each method: the profile
/// follows whoever is signed in.
class UserProfileFirestore {
  UserProfileFirestore({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// The user's sub-collections, deleted with the account.
  static const userCollections = [
    'fridge_items',
    'fridge_history',
    'shopping_lists',
    'notifications',
  ];

  /// Firestore allows at most 500 writes per batch.
  static const _batchSize = 400;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  /// The profile document (null when it doesn't exist yet), sent again each
  /// time it changes.
  Stream<Map<String, dynamic>?> watchProfile(String uid) {
    return _user(uid)
        .snapshots()
        .map((snapshot) => snapshot.exists ? snapshot.data() : null);
  }

  /// Creates the profile on first sign-in. If it already exists, only fills
  /// in a missing name (the name can arrive just after the account is made).
  Future<void> createProfileIfMissing(UserProfile profile) {
    final ref = _user(profile.uid);
    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null || data['createdAt'] == null) {
        transaction.set(
          ref,
          userProfileToMap(profile),
          SetOptions(merge: true),
        );
      } else if ((data['displayName'] as String? ?? '').isEmpty &&
          profile.displayName.isNotEmpty) {
        transaction.update(ref, {'displayName': profile.displayName});
      }
    });
  }

  Future<void> saveDisplayName(String uid, String displayName) =>
      _user(uid).set({'displayName': displayName}, SetOptions(merge: true));

  Future<void> saveBusinessName(String uid, String businessName) =>
      _user(uid).set({'businessName': businessName}, SetOptions(merge: true));

  /// Saves the photo, or removes it when [photoBase64] is null.
  Future<void> savePhoto(String uid, String? photoBase64) => _user(
    uid,
  ).set({'photo': photoBase64 ?? FieldValue.delete()}, SetOptions(merge: true));

  Future<void> saveSettings(String uid, UserSettings settings) => _user(uid)
      .set({'settings': userSettingsToMap(settings)}, SetOptions(merge: true));

  /// Deletes everything the user owns: their sub-collections, their
  /// donations and the profile document. Run it before deleting the account.
  Future<void> deleteUserData(String uid) async {
    final refs = <DocumentReference<Map<String, dynamic>>>[];
    for (final name in userCollections) {
      final snapshot = await _user(uid).collection(name).get();
      refs.addAll(snapshot.docs.map((doc) => doc.reference));
    }
    final donations = await _db
        .collection('donations')
        .where('donorId', isEqualTo: uid)
        .get();
    refs.addAll(donations.docs.map((doc) => doc.reference));
    refs.add(_user(uid));

    for (var start = 0; start < refs.length; start += _batchSize) {
      final batch = _db.batch();
      for (final ref in refs.skip(start).take(_batchSize)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}

// -----------------------------------------------------------------------------
// Conversion between the models and Firestore maps
// -----------------------------------------------------------------------------

Map<String, dynamic> userProfileToMap(UserProfile profile) {
  return {
    'displayName': profile.displayName,
    'email': profile.email,
    if (profile.hasPhoto) 'photo': profile.photoBase64,
    'createdAt': Timestamp.fromDate(profile.createdAt),
    'settings': userSettingsToMap(profile.settings),
    'role': profile.role.name,
    if (profile.businessName.isNotEmpty) 'businessName': profile.businessName,
  };
}

/// [uid] is the document id. [fallbackName] and [fallbackEmail] (from the
/// auth account) fill fields missing from [map].
UserProfile userProfileFromMap(
  String uid,
  Map<String, dynamic> map, {
  String fallbackName = '',
  String fallbackEmail = '',
}) {
  final createdAt = map['createdAt'];
  final name = map['displayName'] as String? ?? '';
  final email = map['email'] as String? ?? '';
  final photo = map['photo'] as String?;
  return UserProfile(
    uid: uid,
    displayName: name.isEmpty ? fallbackName : name,
    email: email.isEmpty ? fallbackEmail : email,
    createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    photoBase64: photo == null || photo.isEmpty ? null : photo,
    settings: userSettingsFromMap(map['settings']),
    role: UserRole.fromName(map['role'] as String?),
    businessName: map['businessName'] as String? ?? '',
  );
}

Map<String, dynamic> userSettingsToMap(UserSettings settings) {
  return {'notificationsEnabled': settings.notificationsEnabled};
}

UserSettings userSettingsFromMap(Object? value) {
  final map = value is Map ? value : const {};
  return UserSettings(
    notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
  );
}
