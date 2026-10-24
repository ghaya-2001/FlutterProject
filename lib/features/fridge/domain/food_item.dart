import 'food_category.dart';

const foodUnits = <String>['pcs', 'kg', 'g', 'L', 'ml', 'pack'];

/// Number of days (inclusive) under which a food must be eaten first.
const priorityThresholdDays = 3;

/// Quantity step used by the +/- buttons for each unit.
double quantityStepFor(String unit) {
  switch (unit) {
    case 'kg':
    case 'L':
      return 0.5;
    case 'g':
    case 'ml':
      return 50;
    default:
      return 1;
  }
}

enum ExpiryStatus { expired, today, soon, fresh }

class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.expiryDate,
    required this.addedAt,
    this.note = '',
  });

  final String id;
  final String name;
  final FoodCategory category;
  final double quantity;
  final String unit;
  final DateTime expiryDate;
  final DateTime addedAt;
  final String note;

  /// Whole days between [now] and the expiry date (negative once expired).
  /// Compared as UTC calendar dates so daylight saving changes don't matter.
  int daysLeft(DateTime now) {
    final expiry = DateTime.utc(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );
    final today = DateTime.utc(now.year, now.month, now.day);
    return expiry.difference(today).inDays;
  }

  ExpiryStatus status(DateTime now) {
    final days = daysLeft(now);
    if (days < 0) return ExpiryStatus.expired;
    if (days == 0) return ExpiryStatus.today;
    if (days <= priorityThresholdDays) return ExpiryStatus.soon;
    return ExpiryStatus.fresh;
  }

  /// Foods that are expired or expire within [priorityThresholdDays].
  bool isPriority(DateTime now) => daysLeft(now) <= priorityThresholdDays;

  bool isExpired(DateTime now) => daysLeft(now) < 0;

  FoodItem copyWith({
    String? name,
    FoodCategory? category,
    double? quantity,
    String? unit,
    DateTime? expiryDate,
    String? note,
  }) {
    return FoodItem(
      id: id,
      addedAt: addedAt,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      note: note ?? this.note,
    );
  }
}
