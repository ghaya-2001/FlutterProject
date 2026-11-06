import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/firebase/firebase_setup.dart';
import '../domain/food_category.dart';
import '../domain/food_item.dart';
import '../domain/fridge_event.dart';
import '../domain/fridge_stats.dart';
import 'fridge_firestore.dart';

enum FridgeSort { expiryDate, name, recentlyAdded }

/// Store for the fridge module.
///
/// Every mutation goes through this class and calls [notifyListeners], so the
/// screens (stock list, counters, details) update automatically.
///
/// The data lives in memory; when [remote] is set (Firebase connected), the
/// fridge is listened to in real time in Firestore and every change is saved
/// there too, so the user's other phones see it immediately.
class FridgeRepository extends ChangeNotifier {
  FridgeRepository({bool seed = true, DateTime Function()? clock, this.remote})
    : _clock = clock ?? DateTime.now {
    if (remote != null) {
      _connectRemote(seedNewUser: seed);
    } else if (seed) {
      _seed();
    }
  }

  static final FridgeRepository instance = FridgeRepository(
    remote: FirebaseSetup.isReady ? FridgeFirestore() : null,
  );

  /// Firestore storage; null in tests or when Firebase is not configured.
  final FridgeFirestore? remote;

  /// True until the first Firestore snapshot of the fridge arrives.
  bool isLoading = false;

  final DateTime Function() _clock;
  final List<FoodItem> _items = [];
  final List<FoodCategory> _categories = [...defaultFoodCategories];
  final List<FridgeEvent> _history = [];
  StreamSubscription<List<Map<String, dynamic>>>? _itemsSubscription;
  int _idCounter = 0;

  DateTime get now => _clock();

  /// True when the fridge is saved in the cloud.
  bool get isSynced => remote != null;

  List<FoodItem> get items => List.unmodifiable(_items);

  List<FoodCategory> get categories => List.unmodifiable(_categories);

  /// Consumed and thrown away foods, most recent first.
  List<FridgeEvent> get history => List.unmodifiable(_history);

  FridgeStats get stats => FridgeStats(_history, now);

  /// Number of ingredients still usable (not expired).
  int get availableCount => _items.where((item) => !item.isExpired(now)).length;

  int get totalCount => _items.length;

  int get priorityCount => _items.where((item) => item.isPriority(now)).length;

  int get expiredCount => _items.where((item) => item.isExpired(now)).length;

  FoodItem? itemById(String id) {
    for (final item in _items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  /// Items matching [search] and [category], ordered by [sort].
  List<FoodItem> query({
    String search = '',
    FoodCategory? category,
    FridgeSort sort = FridgeSort.expiryDate,
  }) {
    final term = search.trim().toLowerCase();
    final result = _items.where((item) {
      if (category != null && item.category != category) {
        return false;
      }
      if (term.isEmpty) {
        return true;
      }
      return item.name.toLowerCase().contains(term) ||
          item.category.name.toLowerCase().contains(term) ||
          item.note.toLowerCase().contains(term);
    }).toList();

    switch (sort) {
      case FridgeSort.expiryDate:
        result.sort((a, b) {
          final byDate = a.expiryDate.compareTo(b.expiryDate);
          return byDate != 0
              ? byDate
              : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case FridgeSort.name:
        result.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case FridgeSort.recentlyAdded:
        result.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Foods
  // ---------------------------------------------------------------------------

  FoodItem addFood({
    required String name,
    required FoodCategory category,
    required double quantity,
    required String unit,
    required DateTime expiryDate,
    String note = '',
  }) {
    final trimmed = name.trim();
    _validate(trimmed, quantity);
    final item = FoodItem(
      id: _newId(),
      name: trimmed,
      category: category,
      quantity: quantity,
      unit: unit,
      expiryDate: DateUtils.dateOnly(expiryDate),
      addedAt: now,
      note: note.trim(),
    );
    _items.add(item);
    notifyListeners();
    _saveItem(item);
    return item;
  }

  void updateFood(FoodItem updated) {
    final index = _items.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      throw ArgumentError('Food ${updated.id} not found');
    }
    final trimmed = updated.name.trim();
    _validate(trimmed, updated.quantity);
    _items[index] = updated.copyWith(
      name: trimmed,
      note: updated.note.trim(),
      expiryDate: DateUtils.dateOnly(updated.expiryDate),
    );
    notifyListeners();
    _saveItem(_items[index]);
  }

  /// Removes a food and returns its previous position so it can be restored
  /// with [restoreFood] (used by the "Undo" action).
  ///
  /// Meant for corrections: nothing is added to the history. Use [throwAway]
  /// when the food was wasted.
  int deleteFood(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) {
      return -1;
    }
    _items.removeAt(index);
    notifyListeners();
    _sync(() => remote!.deleteItem(id));
    return index;
  }

  void restoreFood(FoodItem item, int index) {
    if (_items.any((existing) => existing.id == item.id)) {
      return;
    }
    _items.insert(index.clamp(0, _items.length), item);
    notifyListeners();
    _saveItem(item);
  }

  /// Removes a food that went bad and counts it as wasted in the history.
  void throwAway(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw ArgumentError('Food $id not found');
    }
    final item = _items.removeAt(index);
    _record(FridgeEventType.wasted, item, item.quantity);
    notifyListeners();
    _sync(() => remote!.deleteItem(id));
  }

  /// Updates the stock after eating [amount] of a food.
  ///
  /// Returns the remaining quantity. When nothing is left the food is removed
  /// from the fridge and 0 is returned.
  ///
  /// [record] adds the meal to the history; it is false when the food leaves
  /// the fridge for another reason (a donation).
  double consume(String id, double amount, {bool record = true}) {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than 0');
    }
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw ArgumentError('Food $id not found');
    }
    final item = _items[index];
    // Rounded to avoid floating point leftovers such as 0.30000000000000004.
    final remaining = ((item.quantity - amount) * 1000).roundToDouble() / 1000;
    if (record) {
      final eaten = amount > item.quantity ? item.quantity : amount;
      _record(FridgeEventType.consumed, item, eaten);
    }
    if (remaining <= 0) {
      _items.removeAt(index);
      notifyListeners();
      _sync(() => remote!.deleteItem(id));
      return 0;
    }
    _items[index] = item.copyWith(quantity: remaining);
    notifyListeners();
    _saveItem(_items[index]);
    return remaining;
  }

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  bool hasCategoryNamed(String name) => categoryNamed(name) != null;

  FoodCategory? categoryNamed(String name) {
    final normalized = name.trim().toLowerCase();
    for (final category in _categories) {
      if (category.name.toLowerCase() == normalized) {
        return category;
      }
    }
    return null;
  }

  FoodCategory addCategory(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Category name cannot be empty');
    }
    if (hasCategoryNamed(trimmed)) {
      throw ArgumentError('Category "$trimmed" already exists');
    }
    final category = _insertCustomCategory(trimmed);
    notifyListeners();
    _saveCategories();
    return category;
  }

  /// Deletes a custom category. Foods using it are moved to "Other".
  void removeCategory(FoodCategory category) {
    if (!category.isCustom) {
      throw ArgumentError('Default categories cannot be deleted');
    }
    _categories.remove(category);
    final moved = <FoodItem>[];
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].category == category) {
        _items[i] = _items[i].copyWith(category: otherFoodCategory);
        moved.add(_items[i]);
      }
    }
    notifyListeners();
    _saveCategories();
    if (moved.isNotEmpty) {
      _sync(() => remote!.saveItems(moved));
    }
  }

  int itemCountForCategory(FoodCategory category) =>
      _items.where((item) => item.category == category).length;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _validate(String name, double quantity) {
    if (name.isEmpty) {
      throw ArgumentError('Food name cannot be empty');
    }
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be greater than 0');
    }
  }

  String _newId([String prefix = 'food']) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  FoodCategory _insertCustomCategory(String name) {
    final customCount = _categories.where((c) => c.isCustom).length;
    final category = FoodCategory(
      name: name,
      icon: Icons.label_rounded,
      color:
          customFoodCategoryColors[customCount %
              customFoodCategoryColors.length],
      isCustom: true,
    );
    // Keep "Other" as the last category.
    _categories.insert(_categories.length - 1, category);
    return category;
  }

  /// Category of a stored food. A custom category created on another phone
  /// is added here too, so the food keeps its category.
  FoodCategory _categoryFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return otherFoodCategory;
    }
    return categoryNamed(trimmed) ?? _insertCustomCategory(trimmed);
  }

  void _record(FridgeEventType type, FoodItem item, double quantity) {
    final event = FridgeEvent(
      id: _newId('event'),
      type: type,
      foodName: item.name,
      category: item.category,
      quantity: quantity,
      unit: item.unit,
      at: now,
    );
    _history.insert(0, event);
    _sync(() => remote!.addEvent(event));
  }

  // ---------------------------------------------------------------------------
  // Firestore
  // ---------------------------------------------------------------------------

  /// [seedNewUser] fills the fridge of a user who never used it with the
  /// demo foods, so expiry alerts, donations and the chatbot have data.
  Future<void> _connectRemote({required bool seedNewUser}) async {
    isLoading = true;
    notifyListeners();
    try {
      final settings = await remote!.loadSettings();
      for (final name in settings.customCategories) {
        _categoryFor(name);
      }
      if (seedNewUser && !settings.isSeeded) {
        _seed();
        final demoFoods = List<FoodItem>.of(_items);
        _sync(() => remote!.saveDemoFoods(demoFoods));
      }
      final events = await remote!.loadHistory();
      // Keep events recorded on this phone while the history was loading.
      final known = _history.map((event) => event.id).toSet();
      _history
        ..addAll([
          for (final map in events)
            if (!known.contains(map['id']))
              fridgeEventFromMap(map, _categoryFor),
        ])
        ..sort((a, b) => b.at.compareTo(a.at));
    } catch (error) {
      debugPrint('Could not load fridge categories / history: $error');
    }
    // Firestore sends the local writes first, then the server data, and
    // again on every change made on another phone.
    _itemsSubscription = remote!.watchItems().listen(
      _applyRemoteItems,
      onError: (Object error) {
        debugPrint('Could not listen to the fridge: $error');
        isLoading = false;
        notifyListeners();
      },
    );
  }

  void _applyRemoteItems(List<Map<String, dynamic>> maps) {
    final remoteItems = [
      for (final map in maps) foodItemFromMap(map, _categoryFor),
    ]..sort((a, b) => a.addedAt.compareTo(b.addedAt));
    _items
      ..clear()
      ..addAll(remoteItems);
    isLoading = false;
    notifyListeners();
  }

  /// Runs a Firestore write without blocking the screen. Firestore keeps the
  /// write and sends it later if the phone is offline.
  void _sync(Future<void> Function() write) {
    if (remote == null) {
      return;
    }
    write().catchError(
      (Object error) => debugPrint('Could not save fridge: $error'),
    );
  }

  void _saveItem(FoodItem item) => _sync(() => remote!.saveItem(item));

  void _saveCategories() => _sync(
    () => remote!.saveCustomCategories([
      for (final category in _categories)
        if (category.isCustom) category.name,
    ]),
  );

  @override
  void dispose() {
    _itemsSubscription?.cancel();
    super.dispose();
  }

  void _seed() {
    final today = DateUtils.dateOnly(now);
    FoodCategory category(String name) =>
        categoryNamed(name) ?? otherFoodCategory;

    FoodItem food(
      String name,
      String categoryName,
      double quantity,
      String unit,
      int daysLeft, {
      String note = '',
    }) {
      return FoodItem(
        id: _newId(),
        name: name,
        category: category(categoryName),
        quantity: quantity,
        unit: unit,
        expiryDate: today.add(Duration(days: daysLeft)),
        addedAt: now,
        note: note,
      );
    }

    _items.addAll([
      food('Spinach', 'Vegetables', 1, 'pack', 2),
      food('Yogurt', 'Dairy', 4, 'pcs', 0),
      food('Tomatoes', 'Vegetables', 1, 'kg', 3),
      food('Milk', 'Dairy', 1, 'L', 5),
      food('Lemon', 'Fruits', 3, 'pcs', 7),
      food('Chicken breast', 'Meat & Fish', 0.5, 'kg', 1, note: 'Cook first'),
      food('Eggs', 'Dairy', 6, 'pcs', 14),
    ]);
  }
}
