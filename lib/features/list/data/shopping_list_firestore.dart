import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firebase_setup.dart';
import '../domain/shopping_category.dart';
import '../domain/shopping_item.dart';
import '../domain/shopping_list.dart';

/// What is stored in Firestore for the shopping lists module.
class ShoppingData {
  const ShoppingData({
    required this.lists,
    required this.customCategories,
    this.selectedListId,
  });

  final List<Map<String, dynamic>> lists;
  final List<String> customCategories;
  final String? selectedListId;
}

/// Reads and writes the shopping lists in Firestore.
///
/// Structure:
/// ```
/// users/{userId}                      customShoppingCategories, selectedShoppingListId
/// users/{userId}/shopping_lists/{id}  name, createdAt, items: [...]
/// ```
/// Items are stored inside their list document: a list is small and is
/// always read and written as a whole.
class ShoppingListFirestore {
  ShoppingListFirestore({
    FirebaseFirestore? firestore,
    this.userId = currentUserId,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final String userId;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(userId);

  CollectionReference<Map<String, dynamic>> get _lists =>
      _user.collection('shopping_lists');

  Future<ShoppingData> load() async {
    final user = await _user.get();
    final lists = await _lists.orderBy('createdAt').get();
    final userData = user.data() ?? const <String, dynamic>{};
    return ShoppingData(
      lists: [
        for (final doc in lists.docs) {...doc.data(), 'id': doc.id},
      ],
      customCategories: List<String>.from(
        userData['customShoppingCategories'] as List? ?? const [],
      ),
      selectedListId: userData['selectedShoppingListId'] as String?,
    );
  }

  Future<void> saveList(ShoppingList list) =>
      _lists.doc(list.id).set(shoppingListToMap(list));

  Future<void> deleteList(String listId) => _lists.doc(listId).delete();

  Future<void> saveSettings({
    required List<String> customCategories,
    required String? selectedListId,
  }) {
    return _user.set({
      'customShoppingCategories': customCategories,
      'selectedShoppingListId': selectedListId,
    }, SetOptions(merge: true));
  }
}

// -----------------------------------------------------------------------------
// Conversion between the models and Firestore maps
// -----------------------------------------------------------------------------

Map<String, dynamic> shoppingListToMap(ShoppingList list) {
  return {
    'name': list.name,
    'createdAt': Timestamp.fromDate(list.createdAt),
    'items': [for (final item in list.items) shoppingItemToMap(item)],
  };
}

Map<String, dynamic> shoppingItemToMap(ShoppingItem item) {
  return {
    'id': item.id,
    'name': item.name,
    // Only the name is stored: icon and color come from the app.
    'category': item.category.name,
    'quantity': item.quantity,
    'unit': item.unit,
    'note': item.note,
    'isBought': item.isBought,
    'boughtAt': item.boughtAt == null
        ? null
        : Timestamp.fromDate(item.boughtAt!),
    'createdAt': Timestamp.fromDate(item.createdAt),
  };
}

/// [categoryFor] turns a stored category name back into a category.
ShoppingList shoppingListFromMap(
  Map<String, dynamic> map,
  ShoppingCategory Function(String name) categoryFor,
) {
  return ShoppingList(
    id: map['id'] as String,
    name: map['name'] as String? ?? 'My list',
    createdAt: _date(map['createdAt']) ?? DateTime.now(),
    items: [
      for (final item in map['items'] as List? ?? const [])
        shoppingItemFromMap(
          Map<String, dynamic>.from(item as Map),
          categoryFor,
        ),
    ],
  );
}

ShoppingItem shoppingItemFromMap(
  Map<String, dynamic> map,
  ShoppingCategory Function(String name) categoryFor,
) {
  return ShoppingItem(
    id: map['id'] as String,
    name: map['name'] as String? ?? '',
    category: categoryFor(map['category'] as String? ?? 'Other'),
    quantity: (map['quantity'] as num? ?? 1).toInt(),
    unit: map['unit'] as String? ?? 'pcs',
    note: map['note'] as String? ?? '',
    isBought: map['isBought'] as bool? ?? false,
    boughtAt: _date(map['boughtAt']),
    createdAt: _date(map['createdAt']) ?? DateTime.now(),
  );
}

DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;
