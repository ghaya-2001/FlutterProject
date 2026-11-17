// ignore_for_file: prefer_initializing_formals (private field, named parameter)
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/firebase/firebase_setup.dart';
import '../../../core/session/current_user.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../fridge/domain/food_category.dart';
import '../../fridge/domain/food_item.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../domain/donation_goal.dart';
import 'goal_firestore.dart';

/// Store for the donation goals.
///
/// Restaurants and charities publish goals ("we need 10 kg of rice"), users
/// give towards them, from their fridge or with food they bought, and the
/// progress grows with every contribution until the target is reached.
class GoalRepository extends ChangeNotifier {
  GoalRepository({
    FridgeRepository? fridge,
    this.remote,
    String? userId,
    bool seed = true,
    bool autoConnect = true,
  }) : fridge = fridge ?? FridgeRepository.instance,
       _userId = userId,
       _seedDemo = seed {
    if (remote != null) {
      if (autoConnect) {
        _listen();
      }
    } else if (seed) {
      _seed();
    }
  }

  static final GoalRepository instance = GoalRepository(
    remote: FirebaseSetup.isReady ? GoalFirestore() : null,
    autoConnect: false,
  );

  /// The donor's fridge: a contribution from the fridge leaves its stock.
  final FridgeRepository fridge;

  /// Firestore storage; null in tests or when Firebase is not configured.
  final GoalFirestore? remote;

  final String? _userId;
  final bool _seedDemo;
  final List<DonationGoal> _goals = [];
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  int _idCounter = 0;

  /// True until the first Firestore snapshot arrives.
  bool isLoading = false;

  /// The signed-in account, unless a fixed id was given (tests).
  String get userId => _userId ?? CurrentUser.uid;

  DateTime get now => fridge.now;

  /// Every goal: open ones first (deadline soonest, then newest), then the
  /// reached and ended ones, newest first.
  List<DonationGoal> get goals => _sorted(_goals);

  /// Goals users can still give to.
  List<DonationGoal> get openGoals =>
      goals.where((goal) => goal.isOpen(now)).toList();

  /// Reached, closed or expired goals, most recent first.
  List<DonationGoal> get finishedGoals =>
      goals.where((goal) => !goal.isOpen(now)).toList();

  /// Goals published by the signed-in restaurant.
  List<DonationGoal> get myGoals =>
      goals.where((goal) => goal.restaurantId == userId).toList();

  /// Goals the signed-in user gave to.
  List<DonationGoal> get supportedGoals => goals
      .where((goal) => goal.contributions.any((c) => c.donorId == userId))
      .toList();

  /// Total given by the signed-in user to [goal], in the goal's unit.
  double givenBy(DonationGoal goal, [String? donorId]) {
    final id = donorId ?? userId;
    final total = goal.contributions
        .where((c) => c.donorId == id)
        .fold(0.0, (sum, c) => sum + c.quantity);
    return (total * 1000).roundToDouble() / 1000;
  }

  DonationGoal? goalById(String id) {
    for (final goal in _goals) {
      if (goal.id == id) {
        return goal;
      }
    }
    return null;
  }

  /// Fridge foods that can be given to [goal]: same food, convertible unit,
  /// not expired, soonest expiry first.
  List<FoodItem> fridgeFoodsFor(DonationGoal goal) {
    final result = fridge.items
        .where((food) => !food.isExpired(now) && foodMatchesGoal(food, goal))
        .toList();
    result.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return result;
  }

  /// Open goals asking for [food] (shown on the fridge food details).
  List<DonationGoal> goalsForFood(FoodItem food) => openGoals
      .where(
        (goal) => goal.restaurantId != userId && foodMatchesGoal(food, goal),
      )
      .toList();

  // ---------------------------------------------------------------------------
  // Restaurant / charity actions
  // ---------------------------------------------------------------------------

  /// Publishes a new goal in the name of the signed-in restaurant.
  DonationGoal createGoal({
    required String restaurantName,
    required String title,
    required String foodName,
    required FoodCategory category,
    required double target,
    required String unit,
    String description = '',
    DateTime? deadline,
  }) {
    final food = foodName.trim();
    if (food.isEmpty) {
      throw ArgumentError('Enter the food you need');
    }
    if (target <= 0) {
      throw ArgumentError('The target must be greater than 0');
    }
    final last = deadline == null ? null : DateUtils.dateOnly(deadline);
    if (last != null && last.isBefore(DateUtils.dateOnly(now))) {
      throw ArgumentError('The deadline cannot be in the past');
    }
    final trimmedTitle = title.trim();
    final goal = DonationGoal(
      id: _newId('goal'),
      restaurantId: userId,
      restaurantName: restaurantName.trim(),
      title: trimmedTitle.isEmpty ? '$food needed' : trimmedTitle,
      foodName: food,
      category: category,
      target: target,
      unit: unit,
      description: description.trim(),
      deadline: last,
      createdAt: now,
    );
    _goals.add(goal);
    notifyListeners();
    _sync(() => remote!.create(goal));
    return goal;
  }

  /// Stops an open goal before the target (only its owner).
  void closeGoal(String goalId) {
    final goal = _require(goalId);
    if (goal.restaurantId != userId) {
      throw StateError('Only ${goal.restaurantName} can close this goal');
    }
    if (!goal.isOpen(now)) {
      throw StateError('This goal is already finished');
    }
    _replace(goal.copyWith(closed: true));
    _sync(() => remote!.close(goalId));
  }

  /// Deletes a goal nobody gave to yet (a mistake), only its owner.
  void deleteGoal(String goalId) {
    final goal = _require(goalId);
    if (goal.restaurantId != userId) {
      throw StateError('Only ${goal.restaurantName} can delete this goal');
    }
    if (goal.contributions.isNotEmpty) {
      throw StateError('Donors already gave to this goal: close it instead');
    }
    _goals.removeWhere((g) => g.id == goalId);
    notifyListeners();
    _sync(() => remote!.delete(goalId));
  }

  // ---------------------------------------------------------------------------
  // Donor actions
  // ---------------------------------------------------------------------------

  /// Gives [quantity] (in the goal's unit) to [goalId].
  ///
  /// With [foodId] the food is taken out of the donor's fridge (converted to
  /// the fridge unit, e.g. 500 g from a 1 kg pack). Without it the donor
  /// brings food that is not in the app (bought for the occasion).
  GoalContribution contribute(
    String goalId, {
    required double quantity,
    required String donorName,
    String? foodId,
  }) {
    final goal = _require(goalId);
    if (goal.restaurantId == userId) {
      throw StateError('You cannot give to your own goal');
    }
    if (!goal.isOpen(now)) {
      throw StateError(
        'This goal is ${goalStatusLabel(goal.status(now)).toLowerCase()}',
      );
    }
    if (quantity <= 0) {
      throw ArgumentError('The quantity must be greater than 0');
    }
    if (quantity > goal.remaining) {
      throw ArgumentError(
        'Only ${formatQuantity(goal.remaining)} ${goal.unit} still needed',
      );
    }

    FoodItem? food;
    double? fromFridge;
    if (foodId != null) {
      food = fridge.itemById(foodId);
      if (food == null) {
        throw ArgumentError('Food $foodId not found');
      }
      if (food.isExpired(now)) {
        throw ArgumentError('Expired food cannot be given');
      }
      fromFridge = convertQuantity(quantity, goal.unit, food.unit);
      if (fromFridge == null) {
        throw ArgumentError('${food.unit} cannot be turned into ${goal.unit}');
      }
      if (fromFridge > food.quantity + 0.0001) {
        throw ArgumentError(
          'You only have ${formatQuantity(food.quantity)} ${food.unit} '
          'of ${food.name}',
        );
      }
    }

    final contribution = GoalContribution(
      id: _newId('gift'),
      donorId: userId,
      donorName: donorName.trim().isEmpty ? 'A donor' : donorName.trim(),
      quantity: quantity,
      createdAt: now,
      fromFridge: food != null,
    );
    if (food != null) {
      // The food leaves the fridge without counting as eaten.
      fridge.consume(food.id, fromFridge!, record: false);
    }
    _replace(
      goal.copyWith(contributions: [...goal.contributions, contribution]),
    );
    _sync(() => remote!.addContribution(goalId, contribution));
    return contribution;
  }

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  /// Starts listening to the goals of every restaurant (after [clear]).
  void connect() {
    if (remote != null) {
      _listen();
    } else if (_seedDemo) {
      _seed();
      notifyListeners();
    }
  }

  /// Forgets the goals held in memory (sign-out, another account).
  void clear() {
    _subscription?.cancel();
    _subscription = null;
    _goals.clear();
    isLoading = false;
    notifyListeners();
  }

  void _listen() {
    _subscription?.cancel();
    isLoading = true;
    notifyListeners();
    _subscription = remote!.watchAll().listen(
      (maps) {
        _goals
          ..clear()
          ..addAll([
            for (final map in maps)
              donationGoalFromMap(
                map,
                (name) => fridge.categoryNamed(name) ?? otherFoodCategory,
              ),
          ]);
        isLoading = false;
        notifyListeners();
      },
      onError: (Object error) {
        debugPrint('Could not listen to the donation goals: $error');
        isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<DonationGoal> _sorted(Iterable<DonationGoal> goals) {
    final today = now;
    final result = [...goals];
    result.sort((a, b) {
      final aOpen = a.isOpen(today);
      final bOpen = b.isOpen(today);
      if (aOpen != bOpen) {
        return aOpen ? -1 : 1;
      }
      if (aOpen) {
        final aEnd = a.deadline;
        final bEnd = b.deadline;
        if (aEnd != null && bEnd != null && aEnd != bEnd) {
          return aEnd.compareTo(bEnd);
        }
        if ((aEnd == null) != (bEnd == null)) {
          return aEnd == null ? 1 : -1;
        }
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return result;
  }

  DonationGoal _require(String goalId) {
    final goal = goalById(goalId);
    if (goal == null) {
      throw ArgumentError('Goal $goalId not found');
    }
    return goal;
  }

  void _replace(DonationGoal updated) {
    final index = _goals.indexWhere((g) => g.id == updated.id);
    _goals[index] = updated;
    notifyListeners();
  }

  /// Runs a Firestore write without blocking the screen.
  void _sync(Future<void> Function() write) {
    if (remote == null) {
      return;
    }
    write().catchError(
      (Object error) => debugPrint('Could not save donation goal: $error'),
    );
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  /// Demo goals for the app without Firebase.
  void _seed() {
    final today = DateUtils.dateOnly(now);
    FoodCategory category(String name) =>
        fridge.categoryNamed(name) ?? otherFoodCategory;
    GoalContribution gift(
      String donor,
      String name,
      double qty,
      int hoursAgo,
    ) => GoalContribution(
      id: _newId('gift'),
      donorId: donor,
      donorName: name,
      quantity: qty,
      createdAt: now.subtract(Duration(hours: hoursAgo)),
      fromFridge: true,
    );

    _goals.addAll([
      DonationGoal(
        id: _newId('goal'),
        restaurantId: 'ben-1',
        restaurantName: 'Restos du Cœur',
        title: 'Rice for the soup kitchen',
        foodName: 'Rice',
        category: category('Pantry'),
        target: 10,
        unit: 'kg',
        description: 'We serve 80 hot meals every evening this week.',
        deadline: today.add(const Duration(days: 6)),
        createdAt: now.subtract(const Duration(days: 2)),
        contributions: [
          gift('donor-a', 'Sami', 3, 40),
          gift('donor-b', 'Lina', 2.5, 20),
          gift('donor-c', 'Youssef', 1, 3),
        ],
      ),
      DonationGoal(
        id: _newId('goal'),
        restaurantId: 'ben-3',
        restaurantName: 'Le Jardin Solidaire',
        title: "Milk for the children's breakfast",
        foodName: 'Milk',
        category: category('Dairy'),
        target: 12,
        unit: 'L',
        deadline: today.add(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 1)),
        contributions: [
          gift('donor-a', 'Sami', 6, 22),
          gift('donor-b', 'Lina', 4, 6),
        ],
      ),
      DonationGoal(
        id: _newId('goal'),
        restaurantId: 'ben-2',
        restaurantName: 'Croissant Rouge – local branch',
        title: 'Eggs for the food parcels',
        foodName: 'Eggs',
        category: category('Dairy'),
        target: 60,
        unit: 'pcs',
        createdAt: now.subtract(const Duration(hours: 10)),
        contributions: [gift('donor-c', 'Youssef', 12, 8)],
      ),
      DonationGoal(
        id: _newId('goal'),
        restaurantId: 'ben-1',
        restaurantName: 'Restos du Cœur',
        title: 'Pasta for the weekend meals',
        foodName: 'Pasta',
        category: category('Pantry'),
        target: 8,
        unit: 'pack',
        createdAt: now.subtract(const Duration(days: 5)),
        contributions: [
          gift('donor-a', 'Sami', 3, 110),
          gift('donor-b', 'Lina', 3, 90),
          gift('donor-c', 'Youssef', 2, 70),
        ],
      ),
    ]);
  }
}
