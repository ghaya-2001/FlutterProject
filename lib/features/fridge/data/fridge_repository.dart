import 'package:flutter/material.dart';

import '../domain/food_category.dart';
import '../domain/food_item.dart';

enum FridgeSort { expiryDate, name, recentlyAdded }

/// In-memory store for the fridge module.
///
/// Every mutation goes through this class and calls [notifyListeners], so the
/// screens (stock list, counters, details) update automatically.
class FridgeRepository extends ChangeNotifier {
  FridgeRepository({bool seed = true, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    if (seed) {
      _seed();
    }
  }

  static final FridgeRepository instance = FridgeRepository();

  final DateTime Function() _clock;
  final List<FoodItem> _items = [];
  final List<FoodCategory> _categories = [...defaultFoodCategories];
  int _idCounter = 0;

  DateTime get now => _clock();

  List<FoodItem> get items => List.unmodifiable(_items);

  List<FoodCategory> get categories => List.unmodifiable(_categories);

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
  }

  /// Removes a food and returns its previous position so it can be restored
  /// with [restoreFood] (used by the "Undo" action).
  int deleteFood(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index == -1) {
      return -1;
    }
    _items.removeAt(index);
    notifyListeners();
    return index;
  }

  void restoreFood(FoodItem item, int index) {
    if (_items.any((existing) => existing.id == item.id)) {
      return;
    }
    _items.insert(index.clamp(0, _items.length), item);
    notifyListeners();
  }

  /// Updates the stock after eating [amount] of a food.
  ///
  /// Returns the remaining quantity. When nothing is left the food is removed
  /// from the fridge and 0 is returned.
  double consume(String id, double amount) {
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
    if (remaining <= 0) {
      _items.removeAt(index);
      notifyListeners();
      return 0;
    }
    _items[index] = item.copyWith(quantity: remaining);
    notifyListeners();
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
    final customCount = _categories.where((c) => c.isCustom).length;
    final category = FoodCategory(
      name: trimmed,
      icon: Icons.label_rounded,
      color:
          customFoodCategoryColors[customCount %
              customFoodCategoryColors.length],
      isCustom: true,
    );
    // Keep "Other" as the last category.
    _categories.insert(_categories.length - 1, category);
    notifyListeners();
    return category;
  }

  /// Deletes a custom category. Foods using it are moved to "Other".
  void removeCategory(FoodCategory category) {
    if (!category.isCustom) {
      throw ArgumentError('Default categories cannot be deleted');
    }
    _categories.remove(category);
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].category == category) {
        _items[i] = _items[i].copyWith(category: otherFoodCategory);
      }
    }
    notifyListeners();
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

  String _newId() =>
      'food-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

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
