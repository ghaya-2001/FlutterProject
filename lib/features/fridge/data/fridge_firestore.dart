import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firebase_setup.dart';
import '../domain/food_category.dart';
import '../domain/food_item.dart';
import '../domain/fridge_event.dart';

/// What is stored on the user document for the fridge module.
class FridgeSettings {
  const FridgeSettings({
    required this.customCategories,
    required this.isSeeded,
    this.importedShoppingItemIds = const [],
  });

  final List<String> customCategories;

  /// True once the demo foods were written for this user.
  final bool isSeeded;

  /// Bought shopping items already moved to the fridge.
  final List<String> importedShoppingItemIds;
}

/// Reads and writes the fridge in Firestore.
///
/// Structure:
/// ```
/// users/{userId}                       customFoodCategories, fridgeSeeded,
///                                      importedShoppingItemIds
/// users/{userId}/fridge_items/{id}     name, category, quantity, unit,
///                                      expiryDate, addedAt, note
/// users/{userId}/fridge_history/{id}   type, foodName, category, quantity,
///                                      unit, at, daysLeft, recipe
/// ```
/// One document per food: foods are edited one by one, and the fridge is
/// listened to in real time so every phone of the user stays up to date.
class FridgeFirestore {
  FridgeFirestore({FirebaseFirestore? firestore, this.userId = currentUserId})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// Number of history events loaded for the statistics.
  static const historyLimit = 500;

  final FirebaseFirestore _db;
  final String userId;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(userId);

  CollectionReference<Map<String, dynamic>> get _items =>
      _user.collection('fridge_items');

  CollectionReference<Map<String, dynamic>> get _history =>
      _user.collection('fridge_history');

  Future<FridgeSettings> loadSettings() async {
    final user = await _user.get();
    final data = user.data() ?? const <String, dynamic>{};
    return FridgeSettings(
      customCategories: List<String>.from(
        data['customFoodCategories'] as List? ?? const [],
      ),
      isSeeded: data['fridgeSeeded'] as bool? ?? false,
      importedShoppingItemIds: List<String>.from(
        data['importedShoppingItemIds'] as List? ?? const [],
      ),
    );
  }

  /// Adds groceries bought from the shopping list and remembers which
  /// shopping items they came from, in one batch: a grocery can never be
  /// imported twice, even from another phone.
  Future<void> importGroceries(
    List<FoodItem> items,
    List<String> shoppingItemIds,
  ) {
    final batch = _db.batch();
    for (final item in items) {
      batch.set(_items.doc(item.id), foodItemToMap(item));
    }
    batch.set(_user, {
      'importedShoppingItemIds': FieldValue.arrayUnion(shoppingItemIds),
    }, SetOptions(merge: true));
    return batch.commit();
  }

  /// Writes the demo foods of a new user and remembers it in the same batch,
  /// so they are added only once (not again after the fridge is emptied).
  Future<void> saveDemoFoods(List<FoodItem> items) {
    final batch = _db.batch();
    for (final item in items) {
      batch.set(_items.doc(item.id), foodItemToMap(item));
    }
    batch.set(_user, {'fridgeSeeded': true}, SetOptions(merge: true));
    return batch.commit();
  }

  /// Every food of the fridge, sent again each time one of them changes
  /// (on this phone or on another one).
  Stream<List<Map<String, dynamic>>> watchItems() {
    return _items.snapshots().map(
      (snapshot) => [
        for (final doc in snapshot.docs) {...doc.data(), 'id': doc.id},
      ],
    );
  }

  /// Most recent history events first.
  Future<List<Map<String, dynamic>>> loadHistory() async {
    final snapshot = await _history
        .orderBy('at', descending: true)
        .limit(historyLimit)
        .get();
    return [
      for (final doc in snapshot.docs) {...doc.data(), 'id': doc.id},
    ];
  }

  Future<void> saveItem(FoodItem item) =>
      _items.doc(item.id).set(foodItemToMap(item));

  /// Saves several foods at once: either all of them are written or none.
  Future<void> saveItems(List<FoodItem> items) {
    final batch = _db.batch();
    for (final item in items) {
      batch.set(_items.doc(item.id), foodItemToMap(item));
    }
    return batch.commit();
  }

  Future<void> deleteItem(String itemId) => _items.doc(itemId).delete();

  Future<void> saveCustomCategories(List<String> names) {
    return _user.set({'customFoodCategories': names}, SetOptions(merge: true));
  }

  Future<void> addEvent(FridgeEvent event) =>
      _history.doc(event.id).set(fridgeEventToMap(event));
}

// -----------------------------------------------------------------------------
// Conversion between the models and Firestore maps
// -----------------------------------------------------------------------------

Map<String, dynamic> foodItemToMap(FoodItem item) {
  return {
    'name': item.name,
    // Only the name is stored: icon and color come from the app.
    'category': item.category.name,
    'quantity': item.quantity,
    'unit': item.unit,
    'expiryDate': Timestamp.fromDate(item.expiryDate),
    'addedAt': Timestamp.fromDate(item.addedAt),
    'note': item.note,
  };
}

/// [categoryFor] turns a stored category name back into a fridge category.
FoodItem foodItemFromMap(
  Map<String, dynamic> map,
  FoodCategory Function(String name) categoryFor,
) {
  return FoodItem(
    id: map['id'] as String,
    name: map['name'] as String? ?? '',
    category: categoryFor(map['category'] as String? ?? 'Other'),
    quantity: (map['quantity'] as num? ?? 0).toDouble(),
    unit: map['unit'] as String? ?? 'pcs',
    expiryDate: _date(map['expiryDate']) ?? DateTime.now(),
    addedAt: _date(map['addedAt']) ?? DateTime.now(),
    note: map['note'] as String? ?? '',
  );
}

Map<String, dynamic> fridgeEventToMap(FridgeEvent event) {
  return {
    'type': event.type.name,
    'foodName': event.foodName,
    'category': event.category.name,
    'quantity': event.quantity,
    'unit': event.unit,
    'at': Timestamp.fromDate(event.at),
    'daysLeft': event.daysLeft,
    'recipe': event.recipe,
  };
}

FridgeEvent fridgeEventFromMap(
  Map<String, dynamic> map,
  FoodCategory Function(String name) categoryFor,
) {
  return FridgeEvent(
    id: map['id'] as String,
    type: map['type'] == FridgeEventType.wasted.name
        ? FridgeEventType.wasted
        : FridgeEventType.consumed,
    foodName: map['foodName'] as String? ?? '',
    category: categoryFor(map['category'] as String? ?? 'Other'),
    quantity: (map['quantity'] as num? ?? 0).toDouble(),
    unit: map['unit'] as String? ?? 'pcs',
    at: _date(map['at']) ?? DateTime.now(),
    daysLeft: (map['daysLeft'] as num?)?.toInt(),
    recipe: map['recipe'] as String?,
  );
}

DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;
