import 'package:flutter/material.dart';

import '../../fridge/domain/food_category.dart';
import '../../fridge/domain/food_item.dart';

/// State of a donation goal, computed from its contributions and dates.
enum GoalStatus {
  /// Donors can still give.
  open,

  /// The collected quantity reached the target.
  reached,

  /// The restaurant or charity stopped it before the target.
  closed,

  /// The deadline passed before the target was reached.
  expired,
}

/// One gift of a donor towards a [DonationGoal].
class GoalContribution {
  const GoalContribution({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.quantity,
    required this.createdAt,
    this.fromFridge = false,
  });

  final String id;
  final String donorId;

  /// Copied when the contribution is made, so the restaurant can thank the
  /// donor without reading their private profile.
  final String donorName;

  /// In the unit of the goal (converted from the fridge unit if needed).
  final double quantity;
  final DateTime createdAt;

  /// True when the food was taken out of the donor's fridge.
  final bool fromFridge;
}

/// A need published by a restaurant or a charity: "we need 10 kg of rice".
///
/// Users give part of it; every contribution moves the progress bar until the
/// target is reached. The progress is never stored: it is the sum of the
/// contributions, so two donors giving at the same time cannot overwrite
/// each other's gift.
class DonationGoal {
  const DonationGoal({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.title,
    required this.foodName,
    required this.category,
    required this.target,
    required this.unit,
    required this.createdAt,
    this.description = '',
    this.deadline,
    this.closed = false,
    this.contributions = const [],
  });

  final String id;

  /// Account of the restaurant or charity that needs the food.
  final String restaurantId;
  final String restaurantName;

  /// Short call to action, e.g. "Rice for the soup kitchen".
  final String title;
  final String foodName;
  final FoodCategory category;

  /// Quantity needed, in [unit].
  final double target;
  final String unit;
  final DateTime createdAt;
  final String description;

  /// Last day donors can give (included). Null: no deadline.
  final DateTime? deadline;

  /// Stopped by its owner before the target.
  final bool closed;
  final List<GoalContribution> contributions;

  /// Quantity given so far (can exceed [target] when two donors gave at the
  /// same moment).
  double get collected =>
      _round(contributions.fold(0.0, (sum, c) => sum + c.quantity));

  /// Quantity still needed, never negative.
  double get remaining {
    final left = _round(target - collected);
    return left > 0 ? left : 0;
  }

  /// Between 0 and 1.
  double get progress {
    if (target <= 0) {
      return 0;
    }
    final value = collected / target;
    return value > 1 ? 1 : value;
  }

  /// Whole percentage shown next to the progress bar.
  int get percent => (progress * 100).floor();

  bool get isReached => collected >= target;

  /// Number of different donors.
  int get donorCount => contributions.map((c) => c.donorId).toSet().length;

  /// When the contribution that reached the target was made.
  DateTime? get reachedAt {
    var sum = 0.0;
    final sorted = [...contributions]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final contribution in sorted) {
      sum = _round(sum + contribution.quantity);
      if (sum >= target) {
        return contribution.createdAt;
      }
    }
    return null;
  }

  GoalStatus status(DateTime now) {
    if (isReached) {
      return GoalStatus.reached;
    }
    if (closed) {
      return GoalStatus.closed;
    }
    final last = deadline;
    if (last != null &&
        DateUtils.dateOnly(now).isAfter(DateUtils.dateOnly(last))) {
      return GoalStatus.expired;
    }
    return GoalStatus.open;
  }

  bool isOpen(DateTime now) => status(now) == GoalStatus.open;

  /// Days left before the deadline (0 on the last day), null without one.
  int? daysLeft(DateTime now) {
    final last = deadline;
    if (last == null) {
      return null;
    }
    final end = DateTime.utc(last.year, last.month, last.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    return end.difference(today).inDays;
  }

  /// Contributions, newest first.
  List<GoalContribution> get latestContributions =>
      [...contributions]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  DonationGoal copyWith({bool? closed, List<GoalContribution>? contributions}) {
    return DonationGoal(
      id: id,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      title: title,
      foodName: foodName,
      category: category,
      target: target,
      unit: unit,
      createdAt: createdAt,
      description: description,
      deadline: deadline,
      closed: closed ?? this.closed,
      contributions: contributions ?? this.contributions,
    );
  }
}

// -----------------------------------------------------------------------------
// Matching fridge foods with a goal
// -----------------------------------------------------------------------------

/// Converts [amount] from unit [from] to unit [to].
///
/// Only the same unit, kg ↔ g and L ↔ ml can be converted; returns null for
/// anything else (pieces cannot become kilograms).
double? convertQuantity(double amount, String from, String to) {
  if (from == to) {
    return amount;
  }
  const factors = {
    'kg>g': 1000.0,
    'g>kg': 0.001,
    'L>ml': 1000.0,
    'ml>L': 0.001,
  };
  final factor = factors['$from>$to'];
  return factor == null ? null : _round(amount * factor);
}

bool unitsCompatible(String a, String b) => convertQuantity(1, a, b) != null;

/// Lower case, accents removed, single spaces: "Crème fraîche " → "creme
/// fraiche".
String normalizeFoodName(String name) {
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'á': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'í': 'i',
    'ô': 'o',
    'ö': 'o',
    'ó': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ú': 'u',
    'ç': 'c',
    'œ': 'oe',
  };
  final buffer = StringBuffer();
  for (final char in name.trim().toLowerCase().split('')) {
    buffer.write(accents[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// True when [food] is what [goal] asks for: one name contains the other
/// ("Basmati rice" fits a "Rice" goal, "Rice" fits a "Basmati rice" goal),
/// singular and plural mixed, and the units can be converted.
bool foodMatchesGoal(FoodItem food, DonationGoal goal) {
  if (!unitsCompatible(food.unit, goal.unit)) {
    return false;
  }
  final a = _singular(normalizeFoodName(food.name));
  final b = _singular(normalizeFoodName(goal.foodName));
  if (a.isEmpty || b.isEmpty) {
    return false;
  }
  return a.contains(b) || b.contains(a);
}

String _singular(String name) => name
    .split(' ')
    .map(
      (word) => word.length > 3 && word.endsWith('s')
          ? word.substring(0, word.length - 1)
          : word,
    )
    .join(' ');

double _round(double value) => (value * 1000).roundToDouble() / 1000;

// -----------------------------------------------------------------------------
// Labels and colours
// -----------------------------------------------------------------------------

String goalStatusLabel(GoalStatus status) {
  switch (status) {
    case GoalStatus.open:
      return 'Open';
    case GoalStatus.reached:
      return 'Goal reached';
    case GoalStatus.closed:
      return 'Closed';
    case GoalStatus.expired:
      return 'Ended';
  }
}

Color goalStatusColor(GoalStatus status) {
  switch (status) {
    case GoalStatus.open:
      return const Color(0xFF2E7D32);
    case GoalStatus.reached:
      return const Color(0xFF1565C0);
    case GoalStatus.closed:
    case GoalStatus.expired:
      return Colors.black54;
  }
}

Color goalStatusBackground(GoalStatus status) {
  switch (status) {
    case GoalStatus.open:
      return const Color(0xFFE8F5E9);
    case GoalStatus.reached:
      return const Color(0xFFE3F2FD);
    case GoalStatus.closed:
    case GoalStatus.expired:
      return const Color(0xFFEEEEEE);
  }
}
