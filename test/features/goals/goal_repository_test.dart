import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/core/session/current_user.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/fridge/domain/food_category.dart';
import 'package:foodsaver/features/fridge/domain/food_item.dart';
import 'package:foodsaver/features/goals/data/goal_firestore.dart';
import 'package:foodsaver/features/goals/data/goal_repository.dart';
import 'package:foodsaver/features/goals/domain/donation_goal.dart';

void main() {
  final today = DateTime(2026, 11, 17, 10);
  final pantry = defaultFoodCategories.firstWhere((c) => c.name == 'Pantry');

  late FridgeRepository fridge;

  /// One store shared by the restaurant and the donor (as in Firestore);
  /// [asRestaurant] and [asDonor] switch the signed-in account.
  late GoalRepository goals;

  GoalRepository asRestaurant() {
    CurrentUser.bind('resto');
    return goals;
  }

  GoalRepository asDonor() {
    CurrentUser.bind('donor');
    return goals;
  }

  setUp(() {
    fridge = FridgeRepository(clock: () => today);
    goals = GoalRepository(fridge: fridge, seed: false);
    asDonor();
  });

  tearDown(() => CurrentUser.bind(null));

  DonationGoal publish({
    String food = 'Milk',
    double target = 4,
    String unit = 'L',
    DateTime? deadline,
  }) {
    final goal = asRestaurant().createGoal(
      restaurantName: 'Le Jardin',
      title: '',
      foodName: food,
      category: pantry,
      target: target,
      unit: unit,
      deadline: deadline,
    );
    asDonor();
    return goal;
  }

  FoodItem fridgeFood(String name) =>
      fridge.items.firstWhere((item) => item.name == name);

  group('DonationGoal', () {
    test('progress, remaining and percent follow the contributions', () {
      final goal = publish(target: 10, unit: 'kg', food: 'Rice');
      goals.contribute(goal.id, quantity: 2.5, donorName: 'Maya');
      goals.contribute(goal.id, quantity: 4, donorName: 'Maya');

      final updated = goals.goalById(goal.id)!;
      expect(updated.collected, 6.5);
      expect(updated.remaining, 3.5);
      expect(updated.percent, 65);
      expect(updated.donorCount, 1);
      expect(updated.status(today), GoalStatus.open);
    });

    test('an empty title becomes "<food> needed"', () {
      expect(publish(food: 'Rice').title, 'Rice needed');
    });

    test('the deadline ends the goal the day after', () {
      final goal = publish(deadline: today.add(const Duration(days: 1)));
      expect(goal.status(today.add(const Duration(days: 1))), GoalStatus.open);
      expect(
        goal.status(today.add(const Duration(days: 2))),
        GoalStatus.expired,
      );
      expect(goal.daysLeft(today), 1);
    });
  });

  group('units and matching', () {
    test('kg/g and L/ml convert, pieces do not', () {
      expect(convertQuantity(0.5, 'kg', 'g'), 500);
      expect(convertQuantity(250, 'ml', 'L'), 0.25);
      expect(convertQuantity(3, 'pcs', 'pcs'), 3);
      expect(convertQuantity(1, 'pcs', 'kg'), isNull);
    });

    test('names match ignoring case, accents, plural and extra words', () {
      final goal = publish(food: 'Tomato', unit: 'g', target: 2000);
      expect(foodMatchesGoal(fridgeFood('Tomatoes'), goal), isTrue);
      expect(normalizeFoodName('  Crème  Fraîche '), 'creme fraiche');
      expect(foodMatchesGoal(fridgeFood('Milk'), goal), isFalse);
    });

    test('a fridge food in an incompatible unit is not offered', () {
      final goal = publish(food: 'Eggs', unit: 'kg', target: 2);
      expect(goals.fridgeFoodsFor(goal), isEmpty);
    });
  });

  group('contribute', () {
    test('giving from the fridge removes the food from the fridge', () {
      final goal = publish(food: 'Milk', target: 4, unit: 'L');
      final milk = fridgeFood('Milk'); // 1 L in the demo fridge

      goals.contribute(
        goal.id,
        quantity: 0.4,
        donorName: 'Maya',
        foodId: milk.id,
      );

      expect(fridge.itemById(milk.id)!.quantity, 0.6);
      final contribution = goals.goalById(goal.id)!.contributions.single;
      expect(contribution.fromFridge, isTrue);
      expect(contribution.donorId, 'donor');
      expect(goals.givenBy(goals.goalById(goal.id)!), 0.4);
      // Given away, not eaten: no history event for the statistics.
      expect(fridge.history, isEmpty);
    });

    test('the unit of the fridge is converted (500 g of a 1 kg pack)', () {
      final goal = publish(food: 'Tomatoes', target: 2000, unit: 'g');
      final tomatoes = fridgeFood('Tomatoes'); // 1 kg

      goals.contribute(
        goal.id,
        quantity: 500,
        donorName: 'Maya',
        foodId: tomatoes.id,
      );

      expect(fridge.itemById(tomatoes.id)!.quantity, 0.5);
      expect(goals.goalById(goal.id)!.collected, 500);
    });

    test('giving all of a food removes it from the fridge', () {
      final goal = publish(food: 'Milk', target: 4, unit: 'L');
      final milk = fridgeFood('Milk');
      goals.contribute(goal.id, quantity: 1, donorName: 'M', foodId: milk.id);
      expect(fridge.itemById(milk.id), isNull);
    });

    test('food that is not in the fridge leaves the fridge untouched', () {
      final goal = publish(food: 'Rice', target: 5, unit: 'kg');
      final before = fridge.items.length;
      goals.contribute(goal.id, quantity: 2, donorName: 'Maya');
      expect(fridge.items.length, before);
      expect(goals.goalById(goal.id)!.contributions.single.fromFridge, false);
    });

    test('the goal is reached exactly at the target, then closes', () {
      final goal = publish(food: 'Rice', target: 3, unit: 'kg');
      goals.contribute(goal.id, quantity: 1, donorName: 'A');
      goals.contribute(goal.id, quantity: 2, donorName: 'B');

      final reached = goals.goalById(goal.id)!;
      expect(reached.isReached, isTrue);
      expect(reached.progress, 1);
      expect(reached.status(today), GoalStatus.reached);
      expect(reached.reachedAt, today);
      expect(goals.openGoals, isEmpty);
      expect(goals.finishedGoals.single.id, goal.id);
      expect(
        () => goals.contribute(goal.id, quantity: 1, donorName: 'C'),
        throwsStateError,
      );
    });

    test('a donor cannot give more than what is still needed', () {
      final goal = publish(food: 'Rice', target: 3, unit: 'kg');
      goals.contribute(goal.id, quantity: 2, donorName: 'A');
      expect(
        () => goals.contribute(goal.id, quantity: 1.5, donorName: 'A'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Only 1 kg still needed',
          ),
        ),
      );
    });

    test('a donor cannot give more than they have in the fridge', () {
      final goal = publish(food: 'Milk', target: 4, unit: 'L');
      final milk = fridgeFood('Milk'); // 1 L
      expect(
        () => goals.contribute(
          goal.id,
          quantity: 2,
          donorName: 'A',
          foodId: milk.id,
        ),
        throwsArgumentError,
      );
      expect(fridge.itemById(milk.id)!.quantity, 1);
    });

    test('a restaurant cannot give to its own goal', () {
      final goal = publish();
      expect(
        () => asRestaurant().contribute(goal.id, quantity: 1, donorName: 'Me'),
        throwsStateError,
      );
    });

    test('zero or negative quantities are refused', () {
      final goal = publish();
      expect(
        () => goals.contribute(goal.id, quantity: 0, donorName: 'A'),
        throwsArgumentError,
      );
    });
  });

  group('restaurant', () {
    test('publishes goals and only sees its own in myGoals', () {
      final goal = publish();
      expect(asRestaurant().myGoals.single.id, goal.id);
      expect(asDonor().myGoals, isEmpty);
      expect(goal.restaurantId, 'resto');
    });

    test('refuses an empty food, a zero target or a past deadline', () {
      expect(() => publish(food: ' '), throwsArgumentError);
      expect(() => publish(target: 0), throwsArgumentError);
      expect(
        () => publish(deadline: today.subtract(const Duration(days: 1))),
        throwsArgumentError,
      );
    });

    test('closes a goal: donors can no longer give', () {
      final goal = publish();
      expect(() => asDonor().closeGoal(goal.id), throwsStateError);
      asRestaurant().closeGoal(goal.id);
      expect(goals.goalById(goal.id)!.status(today), GoalStatus.closed);
      expect(
        () => asDonor().contribute(goal.id, quantity: 1, donorName: 'A'),
        throwsStateError,
      );
    });

    test('deletes a goal only while nobody gave', () {
      final goal = publish();
      final other = publish(food: 'Rice', unit: 'kg');
      asDonor().contribute(other.id, quantity: 1, donorName: 'A');

      asRestaurant().deleteGoal(goal.id);
      expect(goals.goalById(goal.id), isNull);
      expect(() => goals.deleteGoal(other.id), throwsStateError);
    });
  });

  test('goalsForFood lists the open goals asking for a fridge food', () {
    final milkGoal = publish(food: 'Milk', unit: 'ml', target: 3000);
    publish(food: 'Rice', unit: 'kg');
    final found = goals.goalsForFood(fridgeFood('Milk'));
    expect(found.map((g) => g.id), [milkGoal.id]);
  });

  test('open goals come first, the closest deadline first', () {
    final late = publish(deadline: today.add(const Duration(days: 9)));
    final soon = publish(deadline: today.add(const Duration(days: 2)));
    final none = publish();
    final done = publish(food: 'Rice', unit: 'kg', target: 1);
    goals.contribute(done.id, quantity: 1, donorName: 'A');

    expect(goals.goals.map((g) => g.id), [soon.id, late.id, none.id, done.id]);
  });

  test('the demo goals have every status a demo needs', () {
    final demo = GoalRepository(fridge: fridge);
    expect(demo.openGoals.length, 3);
    expect(demo.finishedGoals.single.isReached, isTrue);
  });

  test('clear forgets every goal, connect seeds the demo again', () {
    final demo = GoalRepository(fridge: fridge);
    demo.clear();
    expect(demo.goals, isEmpty);
    demo.connect();
    expect(demo.goals, hasLength(4));
  });

  test('Firestore maps keep every field', () {
    final goal = publish(
      food: 'Rice',
      unit: 'kg',
      target: 10,
      deadline: DateTime(2026, 11, 20),
    );
    goals.contribute(goal.id, quantity: 2, donorName: 'Maya');
    final original = goals.goalById(goal.id)!;

    final map = {...donationGoalToMap(original), 'id': original.id};
    expect(map['target'], 10);
    expect(map['category'], 'Pantry');
    expect(map['deadline'], isA<Timestamp>());

    final back = donationGoalFromMap(map, (name) => pantry);
    expect(back.restaurantId, 'resto');
    expect(back.restaurantName, 'Le Jardin');
    expect(back.title, 'Rice needed');
    expect(back.deadline, DateTime(2026, 11, 20));
    expect(back.collected, 2);
    expect(back.contributions.single.donorName, 'Maya');
    expect(back.contributions.single.createdAt, today);
    expect(back.closed, isFalse);
  });

  test('old documents without optional fields still load', () {
    final goal = donationGoalFromMap({
      'id': 'g1',
      'foodName': 'Rice',
      'target': 3,
    }, (name) => pantry);
    expect(goal.unit, 'pcs');
    expect(goal.deadline, isNull);
    expect(goal.contributions, isEmpty);
  });
}
