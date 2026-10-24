import 'shopping_item.dart';

class ShoppingList {
  ShoppingList({
    required this.id,
    required this.name,
    required this.createdAt,
    List<ShoppingItem>? items,
  }) : items = items ?? <ShoppingItem>[];

  final String id;
  String name;
  final DateTime createdAt;

  /// Mutated only through [ShoppingListRepository] so listeners get notified.
  final List<ShoppingItem> items;

  List<ShoppingItem> get pendingItems =>
      items.where((item) => !item.isBought).toList();

  List<ShoppingItem> get boughtItems =>
      items.where((item) => item.isBought).toList();

  int get totalCount => items.length;

  int get boughtCount => items.where((item) => item.isBought).length;

  int get remainingCount => totalCount - boughtCount;

  double get progress => totalCount == 0 ? 0 : boughtCount / totalCount;

  bool get isCompleted => totalCount > 0 && remainingCount == 0;
}
