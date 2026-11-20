/// One shopping item the user marked as bought, with what it cost.
///
/// Purchases are kept apart from the lists: "Clear bought items" removes the
/// items from the list, but the spending history stays.
class Purchase {
  const Purchase({
    required this.id,
    required this.itemId,
    required this.listId,
    required this.name,
    required this.categoryName,
    required this.quantity,
    required this.unit,
    required this.date,
    this.amount,
  });

  final String id;

  /// The shopping item that was ticked (to undo the purchase when unticked).
  final String itemId;
  final String listId;
  final String name;

  /// Shopping category, stored by name like everywhere else.
  final String categoryName;
  final int quantity;
  final String unit;
  final DateTime date;

  /// What the user paid, in DT. Null when no price is known yet.
  final double? amount;

  bool get hasPrice => amount != null;

  Purchase copyWith({double? amount, bool clearAmount = false}) {
    return Purchase(
      id: id,
      itemId: itemId,
      listId: listId,
      name: name,
      categoryName: categoryName,
      quantity: quantity,
      unit: unit,
      date: date,
      amount: clearAmount ? null : (amount ?? this.amount),
    );
  }
}
