import 'user_role.dart';
import 'user_settings.dart';

/// Longest profile photo accepted, as a base64 string (about 500 KB of image).
///
/// The photo is stored inside the `users/{uid}` document, which Firestore
/// limits to 1 MB together with the other modules' fields.
const maxProfilePhotoLength = 700000;

/// Profile of the signed-in user, stored in `users/{uid}`.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.createdAt,
    this.photoBase64,
    this.settings = const UserSettings(),
    this.role = UserRole.user,
    this.businessName = '',
  });

  final String uid;
  final String displayName;
  final String email;
  final DateTime createdAt;

  /// JPEG image encoded in base64, or null when there is no photo.
  final String? photoBase64;

  final UserSettings settings;

  /// Fixed at sign-up; admin is set in the Firebase console.
  final UserRole role;

  /// Name of the restaurant (restaurants only), used as the beneficiary name.
  final String businessName;

  bool get hasPhoto => photoBase64 != null && photoBase64!.isNotEmpty;

  /// Shown when there is no photo, e.g. "M" for "Maya".
  String get initials {
    final words = displayName.trim().split(RegExp(r'\s+'));
    final letters = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return letters.isEmpty ? '?' : letters;
  }

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? photoBase64,
    bool removePhoto = false,
    UserSettings? settings,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      createdAt: createdAt,
      photoBase64: removePhoto ? null : photoBase64 ?? this.photoBase64,
      settings: settings ?? this.settings,
      role: role,
      businessName: businessName,
    );
  }
}
