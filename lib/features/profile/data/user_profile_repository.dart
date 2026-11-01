import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/firebase/firebase_setup.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../domain/user_profile.dart';
import '../domain/user_settings.dart';
import 'user_profile_firestore.dart';

/// Store for the signed-in user's profile and settings (Membre 1).
///
/// Follows [AuthRepository]: when someone signs in, their profile is created
/// if needed and listened to in Firestore; when they sign out, it is cleared.
/// Every change updates the screen first, then is saved in the background.
class UserProfileRepository extends ChangeNotifier {
  UserProfileRepository({
    AuthRepository? auth,
    this.remote,
    DateTime Function()? clock,
  }) : _auth = auth ?? AuthRepository.instance,
       _clock = clock ?? DateTime.now {
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  static final UserProfileRepository instance = UserProfileRepository(
    remote: FirebaseSetup.isReady ? UserProfileFirestore() : null,
  );

  final AuthRepository _auth;
  final DateTime Function() _clock;

  /// Firestore storage; null in tests or when Firebase is not configured.
  final UserProfileFirestore? remote;

  /// True until the first Firestore snapshot of the profile arrives.
  bool isLoading = false;

  UserProfile? _profile;
  StreamSubscription<Map<String, dynamic>?>? _subscription;

  /// Null when nobody is signed in.
  UserProfile? get profile => _profile;

  UserSettings get settings => _profile?.settings ?? const UserSettings();

  Future<void> updateDisplayName(String displayName) async {
    final profile = _requireProfile();
    final name = displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }
    // The account keeps the name too (shown e.g. in password reset emails).
    await _auth.updateDisplayName(name);
    _profile = profile.copyWith(displayName: name);
    notifyListeners();
    _sync(() => remote!.saveDisplayName(profile.uid, name));
  }

  /// Sets the photo (a base64 JPEG), or removes it when [photoBase64] is null.
  void updatePhoto(String? photoBase64) {
    final profile = _requireProfile();
    if (photoBase64 != null && photoBase64.length > maxProfilePhotoLength) {
      throw ArgumentError('Photo is too large');
    }
    _profile = photoBase64 == null
        ? profile.copyWith(removePhoto: true)
        : profile.copyWith(photoBase64: photoBase64);
    notifyListeners();
    _sync(() => remote!.savePhoto(profile.uid, photoBase64));
  }

  void setNotificationsEnabled(bool enabled) {
    final profile = _requireProfile();
    final settings = profile.settings.copyWith(notificationsEnabled: enabled);
    _profile = profile.copyWith(settings: settings);
    notifyListeners();
    _sync(() => remote!.saveSettings(profile.uid, settings));
  }

  /// Deletes all the user's data in Firestore. Waits for the deletion (unlike
  /// other writes) because the account is deleted right after.
  Future<void> deleteAllData() async {
    final profile = _requireProfile();
    await remote?.deleteUserData(profile.uid);
  }

  void _onAuthChanged() {
    final user = _auth.currentUser;
    if (user?.uid == _profile?.uid) {
      _fillMissingName(user);
      return;
    }

    _subscription?.cancel();
    _subscription = null;
    _profile = user == null ? null : _newProfile(user);
    isLoading = false;
    if (user != null && remote != null) {
      _connectRemote(user);
    }
    notifyListeners();
  }

  /// Right after sign-up the account can arrive before its name is set.
  void _fillMissingName(AppUser? user) {
    final profile = _profile;
    if (user == null ||
        profile == null ||
        profile.displayName.isNotEmpty ||
        user.displayName.isEmpty) {
      return;
    }
    _profile = profile.copyWith(displayName: user.displayName);
    notifyListeners();
    _sync(() => remote!.createProfileIfMissing(_profile!));
  }

  UserProfile _newProfile(AppUser user) {
    return UserProfile(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      createdAt: _clock(),
    );
  }

  void _connectRemote(AppUser user) {
    isLoading = true;
    _sync(() => remote!.createProfileIfMissing(_profile!));
    _subscription = remote!
        .watchProfile(user.uid)
        .listen(
          (map) {
            isLoading = false;
            // Missing until the creation above reaches Firestore: keep the
            // profile built from the account.
            if (map != null && _profile?.uid == user.uid) {
              _profile = userProfileFromMap(
                user.uid,
                map,
                fallbackName: _auth.currentUser?.displayName ?? '',
                fallbackEmail: user.email,
              );
            }
            notifyListeners();
          },
          onError: (Object error) {
            isLoading = false;
            notifyListeners();
            debugPrint('Could not load profile: $error');
          },
        );
  }

  UserProfile _requireProfile() {
    final profile = _profile;
    if (profile == null) {
      throw StateError('Nobody is signed in');
    }
    return profile;
  }

  /// Runs a Firestore write without blocking the screen.
  void _sync(Future<void> Function() write) {
    if (remote == null) {
      return;
    }
    write().catchError(
      (Object error) => debugPrint('Could not save profile: $error'),
    );
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _subscription?.cancel();
    super.dispose();
  }
}
