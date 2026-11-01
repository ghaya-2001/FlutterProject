import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/auth/data/auth_repository.dart';
import 'package:foodsaver/features/profile/data/user_profile_firestore.dart';
import 'package:foodsaver/features/profile/data/user_profile_repository.dart';
import 'package:foodsaver/features/profile/domain/user_profile.dart';
import 'package:foodsaver/features/profile/domain/user_settings.dart';

/// In-memory stand-in for Firestore that records every write and lets the
/// test push profile snapshots.
class FakeUserProfileFirestore implements UserProfileFirestore {
  final snapshots = <String, StreamController<Map<String, dynamic>?>>{};
  final created = <UserProfile>[];
  final calls = <String>[];

  StreamController<Map<String, dynamic>?> snapshotsOf(String uid) =>
      snapshots.putIfAbsent(uid, StreamController.broadcast);

  @override
  Stream<Map<String, dynamic>?> watchProfile(String uid) =>
      snapshotsOf(uid).stream;

  @override
  Future<void> createProfileIfMissing(UserProfile profile) async =>
      created.add(profile);

  @override
  Future<void> saveDisplayName(String uid, String displayName) async =>
      calls.add('name $uid $displayName');

  @override
  Future<void> savePhoto(String uid, String? photoBase64) async =>
      calls.add('photo $uid ${photoBase64 ?? 'removed'}');

  @override
  Future<void> saveSettings(String uid, UserSettings settings) async =>
      calls.add('settings $uid ${settings.notificationsEnabled}');

  @override
  Future<void> deleteUserData(String uid) async => calls.add('delete $uid');
}

void main() {
  final today = DateTime(2026, 11, 1, 9);

  group('mapping', () {
    test('profile round-trips through a Firestore map', () {
      final profile = UserProfile(
        uid: 'uid-1',
        displayName: 'Maya',
        email: 'maya@x.com',
        createdAt: today,
        photoBase64: 'abc',
        settings: const UserSettings(notificationsEnabled: false),
      );

      final map = userProfileToMap(profile);
      expect(map['createdAt'], Timestamp.fromDate(today));
      expect(map['settings'], {'notificationsEnabled': false});

      final back = userProfileFromMap('uid-1', map);
      expect(back.displayName, 'Maya');
      expect(back.email, 'maya@x.com');
      expect(back.createdAt, today);
      expect(back.photoBase64, 'abc');
      expect(back.settings.notificationsEnabled, isFalse);
    });

    test('missing fields use defaults and fallbacks', () {
      final profile = userProfileFromMap(
        'uid-1',
        {
          'customFoodCategories': ['Snacks'],
        },
        fallbackName: 'Maya',
        fallbackEmail: 'maya@x.com',
      );

      expect(profile.displayName, 'Maya');
      expect(profile.email, 'maya@x.com');
      expect(profile.hasPhoto, isFalse);
      expect(profile.settings.notificationsEnabled, isTrue);
    });

    test('no photo key is written when there is no photo', () {
      final map = userProfileToMap(
        UserProfile(
          uid: 'u',
          displayName: 'A',
          email: 'a@x.com',
          createdAt: today,
        ),
      );
      expect(map.containsKey('photo'), isFalse);
    });
  });

  test('initials', () {
    UserProfile named(String name) =>
        UserProfile(uid: 'u', displayName: name, email: '', createdAt: today);

    expect(named('Maya').initials, 'M');
    expect(named('maya  ben ali').initials, 'MB');
    expect(named('  ').initials, '?');
  });

  group('in memory (no Firebase)', () {
    late AuthRepository auth;
    late UserProfileRepository profiles;

    setUp(() {
      auth = AuthRepository();
      profiles = UserProfileRepository(auth: auth, clock: () => today);
    });

    test('follows sign-in and sign-out', () async {
      expect(profiles.profile, isNull);

      await auth.signUp(
        displayName: 'Maya',
        email: 'm@x.com',
        password: 'abc123',
      );
      expect(profiles.profile!.displayName, 'Maya');
      expect(profiles.profile!.email, 'm@x.com');
      expect(profiles.profile!.createdAt, today);
      expect(profiles.settings.notificationsEnabled, isTrue);

      await auth.signOut();
      expect(profiles.profile, isNull);
    });

    test('updates name (also on the account), photo and settings', () async {
      await auth.signUp(displayName: 'A', email: 'm@x.com', password: 'abc123');

      await profiles.updateDisplayName(' Maya ');
      profiles.updatePhoto('abc');
      profiles.setNotificationsEnabled(false);

      expect(profiles.profile!.displayName, 'Maya');
      expect(auth.currentUser!.displayName, 'Maya');
      expect(profiles.profile!.photoBase64, 'abc');
      expect(profiles.settings.notificationsEnabled, isFalse);

      profiles.updatePhoto(null);
      expect(profiles.profile!.hasPhoto, isFalse);
    });

    test('rejects an empty name and a photo that is too large', () async {
      await auth.signUp(displayName: 'A', email: 'm@x.com', password: 'abc123');

      expect(() => profiles.updateDisplayName('  '), throwsArgumentError);
      expect(
        () => profiles.updatePhoto('a' * (maxProfilePhotoLength + 1)),
        throwsArgumentError,
      );
    });

    test('changes need someone signed in', () {
      expect(() => profiles.setNotificationsEnabled(false), throwsStateError);
    });
  });

  group('with Firestore', () {
    late AuthRepository auth;
    late FakeUserProfileFirestore remote;
    late UserProfileRepository profiles;

    setUp(() {
      auth = AuthRepository();
      remote = FakeUserProfileFirestore();
      profiles = UserProfileRepository(
        auth: auth,
        remote: remote,
        clock: () => today,
      );
    });

    test('creates the profile on sign-in and listens to it', () async {
      final user = await auth.signUp(
        displayName: 'Maya',
        email: 'm@x.com',
        password: 'abc123',
      );
      await pumpEventQueue();

      expect(remote.created.single.uid, user.uid);
      expect(remote.created.single.displayName, 'Maya');
      expect(profiles.isLoading, isTrue);

      remote.snapshotsOf(user.uid).add({
        'displayName': 'Maya B.',
        'email': 'm@x.com',
        'photo': 'xyz',
        'createdAt': Timestamp.fromDate(today),
        'settings': {'notificationsEnabled': false},
      });
      await pumpEventQueue();

      expect(profiles.isLoading, isFalse);
      expect(profiles.profile!.displayName, 'Maya B.');
      expect(profiles.profile!.photoBase64, 'xyz');
      expect(profiles.settings.notificationsEnabled, isFalse);
    });

    test('keeps the account profile until the document exists', () async {
      final user = await auth.signUp(
        displayName: 'Maya',
        email: 'm@x.com',
        password: 'abc123',
      );
      remote.snapshotsOf(user.uid).add(null);
      await pumpEventQueue();

      expect(profiles.profile!.displayName, 'Maya');
    });

    test('saves every change for the signed-in user', () async {
      final user = await auth.signUp(
        displayName: 'A',
        email: 'm@x.com',
        password: 'abc123',
      );

      await profiles.updateDisplayName('Maya');
      profiles.updatePhoto('abc');
      profiles.updatePhoto(null);
      profiles.setNotificationsEnabled(false);
      await profiles.deleteAllData();
      await pumpEventQueue();

      expect(remote.calls, [
        'name ${user.uid} Maya',
        'photo ${user.uid} abc',
        'photo ${user.uid} removed',
        'settings ${user.uid} false',
        'delete ${user.uid}',
      ]);
    });

    test('a snapshot for a previous user is ignored', () async {
      final first = await auth.signUp(
        displayName: 'A',
        email: 'a@x.com',
        password: 'abc123',
      );
      await auth.signOut();
      await auth.signUp(displayName: 'B', email: 'b@x.com', password: 'abc123');

      remote.snapshotsOf(first.uid).add({'displayName': 'A'});
      await pumpEventQueue();

      expect(profiles.profile!.displayName, 'B');
    });
  });
}
