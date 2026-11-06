import 'food_category.dart';

/// What happened to a food when it left (part of) the fridge stock.
enum FridgeEventType { consumed, wasted }

/// One entry of the fridge history, used by the anti-waste statistics.
///
/// The food is copied (name, category, unit) so the event stays readable
/// after the food itself is deleted.
class FridgeEvent {
  const FridgeEvent({
    required this.id,
    required this.type,
    required this.foodName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.at,
    this.daysLeft,
    this.recipe,
  });

  final String id;
  final FridgeEventType type;
  final String foodName;
  final FoodCategory category;
  final double quantity;
  final String unit;
  final DateTime at;

  /// Days the food had left when it was eaten or thrown away.
  final int? daysLeft;

  /// Name of the recipe the food was cooked in, if any.
  final String? recipe;

  bool get isWaste => type == FridgeEventType.wasted;
}
