import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/session/current_user.dart';
import '../../donations/data/donation_repository.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../list/data/shopping_list_repository.dart';
import '../../notifications/data/notification_repository.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../profile/domain/user_role.dart';
import 'auth_repository.dart';

/// Ties the app's data to whoever is signed in.
///
/// When the signed-in account changes (sign-in, sign-out, another account),
/// it points [CurrentUser] at the new uid, empties every repository so the
/// next account never sees the previous one's data, then loads the new
/// account's data. Lists and notifications are only loaded for normal users;
/// restaurants also get their own (empty at first) fridge as their stock, and
/// admins only need donations.
class SessionBinder {
  SessionBinder({
    AuthRepository? auth,
    UserProfileRepository? profiles,
    FridgeRepository? fridge,
    ShoppingListRepository? shopping,
    NotificationRepository? notifications,
    DonationRepository? donations,
  }) : _auth = auth ?? AuthRepository.instance,
       _profiles = profiles ?? UserProfileRepository.instance,
       _fridge = fridge ?? FridgeRepository.instance,
       _shopping = shopping ?? ShoppingListRepository.instance,
       _notifications = notifications ?? NotificationRepository.instance,
       _donations = donations ?? DonationRepository.instance {
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final AuthRepository _auth;
  final UserProfileRepository _profiles;
  final FridgeRepository _fridge;
  final ShoppingListRepository _shopping;
  final NotificationRepository _notifications;
  final DonationRepository _donations;

  String? _boundUid;

  void _onAuthChanged() {
    final uid = _auth.currentUser?.uid;
    if (uid == _boundUid) {
      return;
    }
    _boundUid = uid;
    CurrentUser.bind(uid);
    _fridge.clear();
    _shopping.clear();
    _notifications.clear();
    _donations.clear();
    if (uid != null) {
      unawaited(_connect(uid));
    }
  }

  Future<void> _connect(String uid) async {
    // The role is only known once the profile is loaded.
    await _profiles.whenReady();
    if (_boundUid != uid) {
      return; // someone else signed in meanwhile
    }
    try {
      switch (_profiles.role) {
        case UserRole.user:
          _fridge.connect();
          _shopping.connect();
          _notifications.connect();
        case UserRole.restaurant:
          _fridge.connect(seedDemo: false);
        case UserRole.admin:
          break;
      }
      _donations.connect();
    } catch (error) {
      debugPrint('Could not load the data of the signed-in user: $error');
    }
  }

  void dispose() => _auth.removeListener(_onAuthChanged);
}
