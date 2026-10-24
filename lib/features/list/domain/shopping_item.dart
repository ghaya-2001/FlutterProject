import 'shopping_category.dart';

const shoppingUnits = <String>['pcs', 'kg', 'g', 'L', 'ml', 'pack'];

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.createdAt,
    this.quantity = 1,
    this.unit = 'pcs',
    this.note = '',
    this.isBought = false,
    this.boughtAt,
  });

  final String id;
  final String name;
  final ShoppingCategory category;
  final DateTime createdAt;
  final int quantity;
  final String unit;
  final String note;
  final bool isBought;
  final DateTime? boughtAt;

  String get quantityLabel => '$quantity $unit';

  ShoppingItem copyWith({
    String? name,
    ShoppingCategory? category,
    int? quantity,
    String? unit,
    String? note,
    bool? isBought,
    DateTime? boughtAt,
    bool clearBoughtAt = false,
  }) {
    return ShoppingItem(
      id: id,
      createdAt: createdAt,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      note: note ?? this.note,
      isBought: isBought ?? this.isBought,
      boughtAt: clearBoughtAt ? null : (boughtAt ?? this.boughtAt),
    );
  }
}
