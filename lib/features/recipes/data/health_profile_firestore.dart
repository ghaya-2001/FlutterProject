// ignore_for_file: prefer_initializing_formals (private field, named parameter)
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/session/current_user.dart';
import '../domain/health_goal.dart';

/// Reads and writes the user's health goal in Firestore.
///
/// Structure:
/// ```
/// users/{userId}/health/profile   goal, updatedAt
/// ```
class HealthProfileFirestore {
  HealthProfileFirestore({FirebaseFirestore? firestore, String? userId})
    : _db = firestore ?? FirebaseFirestore.instance,
      _userId = userId;

  static const collection = 'health';
  static const document = 'profile';

  final FirebaseFirestore _db;
  final String? _userId;

  /// The signed-in user, unless a fixed id was given (tests).
  String get userId => _userId ?? CurrentUser.uid;

  DocumentReference<Map<String, dynamic>> get _profile => _db
      .collection('users')
      .doc(userId)
      .collection(collection)
      .doc(document);

  /// The saved goal, or [HealthGoal.none] when nothing is saved yet.
  Future<HealthGoal> load() async {
    final snapshot = await _profile.get();
    return healthGoalFromMap(snapshot.data());
  }

  Future<void> save(HealthGoal goal, DateTime at) =>
      _profile.set(healthGoalToMap(goal, at));
}

Map<String, dynamic> healthGoalToMap(HealthGoal goal, DateTime at) => {
  'goal': goal.name,
  'updatedAt': Timestamp.fromDate(at),
};

HealthGoal healthGoalFromMap(Map<String, dynamic>? map) =>
    HealthGoal.fromName(map?['goal'] as String?);
