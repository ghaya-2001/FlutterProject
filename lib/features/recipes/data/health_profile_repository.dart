import 'package:flutter/foundation.dart';

import '../../../core/firebase/firebase_setup.dart';
import '../domain/health_goal.dart';
import 'health_profile_firestore.dart';

/// The user's health goal (Membre 5), chosen in the profile.
///
/// Kept in memory for the screens; when [remote] is set (Firebase
/// connected), every change is also saved in Firestore in the background.
class HealthProfileRepository extends ChangeNotifier {
  /// [autoConnect] false waits for [connect] (the app-wide instance, bound
  /// to the signed-in user by `SessionBinder`).
  HealthProfileRepository({
    this.remote,
    DateTime Function()? clock,
    bool autoConnect = true,
  }) : _clock = clock ?? DateTime.now {
    if (remote != null && autoConnect) {
      _loadRemote();
    }
  }

  static final HealthProfileRepository instance = HealthProfileRepository(
    remote: FirebaseSetup.isReady ? HealthProfileFirestore() : null,
    autoConnect: false,
  );

  /// Firestore storage; null in tests or when Firebase is not configured.
  final HealthProfileFirestore? remote;

  final DateTime Function() _clock;

  HealthGoal _goal = HealthGoal.none;

  /// Bumped by every local change, so a load that started before it does
  /// not overwrite it.
  int _version = 0;

  HealthGoal get goal => _goal;

  void setGoal(HealthGoal goal) {
    if (goal == _goal) {
      return;
    }
    _goal = goal;
    _version++;
    notifyListeners();
    final at = _clock();
    _sync(() => remote!.save(goal, at));
  }

  /// Loads the signed-in user's goal (after [clear]).
  void connect() {
    if (remote != null) {
      _loadRemote();
    }
  }

  /// Forgets the previous user's goal.
  void clear() {
    _goal = HealthGoal.none;
    _version++;
    notifyListeners();
  }

  Future<void> _loadRemote() async {
    final version = _version;
    try {
      final loaded = await remote!.load();
      if (version != _version) {
        return; // changed meanwhile (new choice or another account)
      }
      _goal = loaded;
      notifyListeners();
    } catch (error) {
      debugPrint('Could not load the health goal: $error');
    }
  }

  /// Runs a Firestore write without blocking the screen.
  void _sync(Future<void> Function() write) {
    if (remote == null) {
      return;
    }
    write().catchError(
      (Object error) => debugPrint('Could not save the health goal: $error'),
    );
  }
}
