import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/recipes/data/health_profile_firestore.dart';
import 'package:foodsaver/features/recipes/data/health_profile_repository.dart';
import 'package:foodsaver/features/recipes/domain/health_goal.dart';

/// In-memory stand-in for Firestore that records every write.
class FakeHealthProfileFirestore implements HealthProfileFirestore {
  FakeHealthProfileFirestore([this.stored = HealthGoal.none]);

  HealthGoal stored;
  final saved = <HealthGoal>[];

  @override
  String get userId => 'test-user';

  @override
  Future<HealthGoal> load() async => stored;

  @override
  Future<void> save(HealthGoal goal, DateTime at) async => saved.add(goal);
}

void main() {
  final now = DateTime(2026, 11, 16, 9);

  test('starts without a goal and notifies on change only', () {
    final repository = HealthProfileRepository(clock: () => now);
    var notified = 0;
    repository.addListener(() => notified++);

    expect(repository.goal, HealthGoal.none);
    repository.setGoal(HealthGoal.loseWeight);
    repository.setGoal(HealthGoal.loseWeight);
    expect(repository.goal, HealthGoal.loseWeight);
    expect(notified, 1);

    repository.clear();
    expect(repository.goal, HealthGoal.none);
  });

  test('loads the stored goal on connect', () async {
    final remote = FakeHealthProfileFirestore(HealthGoal.buildMuscle);
    final repository = HealthProfileRepository(
      remote: remote,
      clock: () => now,
      autoConnect: false,
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.goal, HealthGoal.none);

    repository.connect();
    await Future<void>.delayed(Duration.zero);
    expect(repository.goal, HealthGoal.buildMuscle);
  });

  test('saves the goal in the background', () async {
    final remote = FakeHealthProfileFirestore();
    final repository = HealthProfileRepository(remote: remote, clock: () => now)
      ..setGoal(HealthGoal.stayBalanced);
    await Future<void>.delayed(Duration.zero);
    expect(repository.goal, HealthGoal.stayBalanced);
    expect(remote.saved, [HealthGoal.stayBalanced]);
  });

  test('Firestore mapping round-trips', () {
    final map = healthGoalToMap(HealthGoal.loseWeight, now);
    expect(map['goal'], 'loseWeight');
    expect(map['updatedAt'], isA<Timestamp>());
    expect(healthGoalFromMap(map), HealthGoal.loseWeight);
    expect(healthGoalFromMap(null), HealthGoal.none);
  });
}
