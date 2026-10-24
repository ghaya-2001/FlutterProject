import 'package:flutter/material.dart';

import '../domain/shopping_category.dart';
import '../domain/shopping_item.dart';
import '../domain/shopping_list.dart';

/// In-memory store for the shopping lists module.
///
/// Every mutation goes through this class and calls [notifyListeners], so the
/// screens update automatically (counters, progress, bought section...).
class ShoppingListRepository extends ChangeNotifier {
  ShoppingListRepository({bool seed = true}) {
    if (seed) {
      _seed();
    }
  }

  static final ShoppingListRepository instance = ShoppingListRepository();

  final List<ShoppingList> _lists = [];
  final List<ShoppingCategory> _categories = [...defaultShoppingCategories];
  String? _selectedListId;
  int _idCounter = 0;

  List<ShoppingList> get lists => List.unmodifiable(_lists);

  List<ShoppingCategory> get categories => List.unmodifiable(_categories);

  ShoppingList? get selectedList {
    for (final list in _lists) {
      if (list.id == _selectedListId) {
        return list;
      }
    }
    return _lists.isEmpty ? null : _lists.first;
  }

  /// Items still to buy across every list.
  int get totalRemainingCount =>
      _lists.fold(0, (sum, list) => sum + list.remainingCount);

  ShoppingList? listById(String id) {
    for (final list in _lists) {
      if (list.id == id) {
        return list;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Lists
  // ---------------------------------------------------------------------------

  bool hasListNamed(String name, {String? exceptId}) {
    final normalized = name.trim().toLowerCase();
    return _lists.any(
      (list) => list.id != exceptId && list.name.toLowerCase() == normalized,
    );
  }

  ShoppingList createList(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('List name cannot be empty');
    }
    if (hasListNamed(trimmed)) {
      throw ArgumentError('A list named "$trimmed" already exists');
    }
    final list = ShoppingList(
      id: _newId('list'),
      name: trimmed,
      createdAt: DateTime.now(),
    );
    _lists.add(list);
    _selectedListId = list.id;
    notifyListeners();
    return list;
  }

  void renameList(String listId, String name) {
    final list = _requireList(listId);
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('List name cannot be empty');
    }
    if (hasListNamed(trimmed, exceptId: listId)) {
      throw ArgumentError('A list named "$trimmed" already exists');
    }
    list.name = trimmed;
    notifyListeners();
  }

  void deleteList(String listId) {
    final list = _requireList(listId);
    _lists.remove(list);
    if (_selectedListId == listId) {
      _selectedListId = _lists.isEmpty ? null : _lists.first.id;
    }
    notifyListeners();
  }

  void selectList(String listId) {
    _requireList(listId);
    if (_selectedListId == listId) {
      return;
    }
    _selectedListId = listId;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Items
  // ---------------------------------------------------------------------------

  /// Adds an item to [listId].
  ///
  /// If an item with the same name, category and unit already exists, the
  /// quantities are merged instead of creating a duplicate. A bought duplicate
  /// is moved back to the "to buy" section.
  ShoppingItem addItem(
    String listId, {
    required String name,
    required ShoppingCategory category,
    int quantity = 1,
    String unit = 'pcs',
    String note = '',
  }) {
    final list = _requireList(listId);
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Item name cannot be empty');
    }
    if (quantity < 1) {
      throw ArgumentError('Quantity must be at least 1');
    }

    final existingIndex = list.items.indexWhere(
      (item) =>
          item.name.toLowerCase() == trimmed.toLowerCase() &&
          item.category == category &&
          item.unit == unit,
    );

    if (existingIndex != -1) {
      final existing = list.items[existingIndex];
      final merged = existing.copyWith(
        quantity: existing.isBought ? quantity : existing.quantity + quantity,
        note: note.trim().isEmpty ? existing.note : note.trim(),
        isBought: false,
        clearBoughtAt: true,
      );
      list.items[existingIndex] = merged;
      notifyListeners();
      return merged;
    }

    final item = ShoppingItem(
      id: _newId('item'),
      name: trimmed,
      category: category,
      quantity: quantity,
      unit: unit,
      note: note.trim(),
      createdAt: DateTime.now(),
    );
    list.items.add(item);
    notifyListeners();
    return item;
  }

  void updateItem(String listId, ShoppingItem updated) {
    final list = _requireList(listId);
    final index = list.items.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      throw ArgumentError('Item ${updated.id} not found');
    }
    if (updated.name.trim().isEmpty) {
      throw ArgumentError('Item name cannot be empty');
    }
    if (updated.quantity < 1) {
      throw ArgumentError('Quantity must be at least 1');
    }
    list.items[index] = updated.copyWith(
      name: updated.name.trim(),
      note: updated.note.trim(),
    );
    notifyListeners();
  }

  /// Removes an item and returns its previous position so it can be restored
  /// with [restoreItem] (used by the "Undo" action).
  int removeItem(String listId, String itemId) {
    final list = _requireList(listId);
    final index = list.items.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      return -1;
    }
    list.items.removeAt(index);
    notifyListeners();
    return index;
  }

  void restoreItem(String listId, ShoppingItem item, int index) {
    final list = listById(listId);
    if (list == null || list.items.any((existing) => existing.id == item.id)) {
      return;
    }
    list.items.insert(index.clamp(0, list.items.length), item);
    notifyListeners();
  }

  void toggleBought(String listId, String itemId) {
    final list = _requireList(listId);
    final index = list.items.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      return;
    }
    final item = list.items[index];
    list.items[index] = item.isBought
        ? item.copyWith(isBought: false, clearBoughtAt: true)
        : item.copyWith(isBought: true, boughtAt: DateTime.now());
    notifyListeners();
  }

  void markAllBought(String listId) {
    final list = _requireList(listId);
    final now = DateTime.now();
    for (var i = 0; i < list.items.length; i++) {
      if (!list.items[i].isBought) {
        list.items[i] = list.items[i].copyWith(isBought: true, boughtAt: now);
      }
    }
    notifyListeners();
  }

  /// Removes every bought item from the list and returns them.
  List<ShoppingItem> clearBought(String listId) {
    final list = _requireList(listId);
    final removed = list.boughtItems;
    if (removed.isEmpty) {
      return removed;
    }
    list.items.removeWhere((item) => item.isBought);
    notifyListeners();
    return removed;
  }

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  bool hasCategoryNamed(String name) {
    final normalized = name.trim().toLowerCase();
    return _categories.any(
      (category) => category.name.toLowerCase() == normalized,
    );
  }

  ShoppingCategory? categoryNamed(String name) {
    final normalized = name.trim().toLowerCase();
    for (final category in _categories) {
      if (category.name.toLowerCase() == normalized) {
        return category;
      }
    }
    return null;
  }

  ShoppingCategory addCategory(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Category name cannot be empty');
    }
    if (hasCategoryNamed(trimmed)) {
      throw ArgumentError('Category "$trimmed" already exists');
    }
    final customCount = _categories.where((c) => c.isCustom).length;
    final category = ShoppingCategory(
      name: trimmed,
      icon: Icons.label_rounded,
      color: customCategoryColors[customCount % customCategoryColors.length],
      isCustom: true,
    );
    // Keep "Other" as the last category.
    _categories.insert(_categories.length - 1, category);
    notifyListeners();
    return category;
  }

  /// Deletes a custom category. Items using it are moved to "Other".
  void removeCategory(ShoppingCategory category) {
    if (!category.isCustom) {
      throw ArgumentError('Default categories cannot be deleted');
    }
    _categories.remove(category);
    for (final list in _lists) {
      for (var i = 0; i < list.items.length; i++) {
        if (list.items[i].category == category) {
          list.items[i] = list.items[i].copyWith(
            category: otherShoppingCategory,
          );
        }
      }
    }
    notifyListeners();
  }

  int itemCountForCategory(ShoppingCategory category) {
    return _lists.fold(
      0,
      (sum, list) =>
          sum + list.items.where((item) => item.category == category).length,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  ShoppingList _requireList(String listId) {
    final list = listById(listId);
    if (list == null) {
      throw ArgumentError('List $listId not found');
    }
    return list;
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  void _seed() {
    final list = ShoppingList(
      id: _newId('list'),
      name: 'Weekly groceries',
      createdAt: DateTime.now(),
    );
    _lists.add(list);
    _selectedListId = list.id;

    ShoppingCategory category(String name) =>
        categoryNamed(name) ?? otherShoppingCategory;

    final now = DateTime.now();
    list.items.addAll([
      ShoppingItem(
        id: _newId('item'),
        name: 'Milk',
        category: category('Dairy'),
        quantity: 2,
        unit: 'L',
        isBought: true,
        boughtAt: now,
        createdAt: now,
      ),
      ShoppingItem(
        id: _newId('item'),
        name: 'Tomatoes',
        category: category('Vegetables'),
        quantity: 1,
        unit: 'kg',
        createdAt: now,
      ),
      ShoppingItem(
        id: _newId('item'),
        name: 'Rice',
        category: category('Pantry'),
        quantity: 1,
        unit: 'pack',
        createdAt: now,
      ),
      ShoppingItem(
        id: _newId('item'),
        name: 'Avocados',
        category: category('Fruits'),
        quantity: 3,
        isBought: true,
        boughtAt: now,
        createdAt: now,
      ),
      ShoppingItem(
        id: _newId('item'),
        name: 'Pasta',
        category: category('Pantry'),
        quantity: 2,
        unit: 'pack',
        note: 'Whole wheat if available',
        createdAt: now,
      ),
    ]);
  }
}
