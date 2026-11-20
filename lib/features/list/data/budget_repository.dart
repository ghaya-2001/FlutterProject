import 'package:flutter/material.dart';

import '../../../core/firebase/firebase_setup.dart';
import '../domain/budget.dart';
import '../domain/purchase.dart';
import '../domain/shopping_item.dart';
import '../domain/spending_analysis.dart';
import 'budget_firestore.dart';

/// Store for the food budget and the purchases (spending history).
///
/// [ShoppingListRepository] records a purchase here when an item is marked
/// as bought, and removes it when the item is unticked. The data lives in
/// memory; when [remote] is set it is loaded from Firestore and every change
/// is saved there too.
class BudgetRepository extends ChangeNotifier {
  /// [autoConnect] false waits for [connect] (the app-wide instance is
  /// connected together with the shopping lists).
  BudgetRepository({
    this.remote,
    bool autoConnect = true,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (remote != null && autoConnect) {
      _loadRemote();
    }
  }

  static final BudgetRepository instance = BudgetRepository(
    remote: FirebaseSetup.isReady ? BudgetFirestore() : null,
    autoConnect: false,
  );

  /// Firestore storage; null in tests or when Firebase is not configured.
  final BudgetFirestore? remote;
  final DateTime Function() _clock;

  ShoppingBudget? _budget;
  final List<Purchase> _purchases = [];
  int _idCounter = 0;

  /// True while the data is being loaded from Firestore.
  bool isLoading = false;

  DateTime get now => _clock();

  ShoppingBudget? get budget => _budget;

  /// Every purchase, oldest first.
  List<Purchase> get purchases => List.unmodifiable(_purchases);

  Purchase? purchaseById(String id) {
    for (final purchase in _purchases) {
      if (purchase.id == id) {
        return purchase;
      }
    }
    return null;
  }

  /// The most recent purchase recorded for a shopping item, if any.
  Purchase? latestPurchaseFor(String itemId) {
    for (final purchase in _purchases.reversed) {
      if (purchase.itemId == itemId) {
        return purchase;
      }
    }
    return null;
  }

  /// Spending of the current period, compared with the budget.
  SpendingReport reportFor(Iterable<ShoppingItem> itemsToBuy) {
    return analyzeSpending(
      purchases: _purchases,
      itemsToBuy: itemsToBuy,
      now: now,
      budget: _budget,
    );
  }

  // ---------------------------------------------------------------------------
  // Budget
  // ---------------------------------------------------------------------------

  void setBudget(double amount, BudgetPeriod period) {
    if (amount <= 0 || amount.isNaN || amount.isInfinite) {
      throw ArgumentError('The budget must be greater than 0');
    }
    _budget = ShoppingBudget(amount: amount, period: period);
    notifyListeners();
    _sync(() => remote!.saveBudget(_budget));
  }

  void removeBudget() {
    if (_budget == null) {
      return;
    }
    _budget = null;
    notifyListeners();
    _sync(() => remote!.saveBudget(null));
  }

  // ---------------------------------------------------------------------------
  // Purchases
  // ---------------------------------------------------------------------------

  /// Records that [item] of [listId] was bought.
  ///
  /// The amount starts as the item's estimated total and can be changed with
  /// [updatePurchaseAmount]. It stays null when the item has no price.
  Purchase recordPurchase(ShoppingItem item, String listId) {
    final purchase = Purchase(
      id: _newId(),
      itemId: item.id,
      listId: listId,
      name: item.name,
      categoryName: item.category.name,
      quantity: item.quantity,
      unit: item.unit,
      amount: item.estimatedTotal,
      date: now,
    );
    _purchases.add(purchase);
    notifyListeners();
    _sync(() => remote!.savePurchase(purchase));
    return purchase;
  }

  /// Removes the latest purchase of [itemId] (the item was unticked).
  /// Returns the removed purchase, or null when there was none.
  Purchase? undoPurchaseOf(String itemId) {
    final purchase = latestPurchaseFor(itemId);
    if (purchase == null) {
      return null;
    }
    _purchases.remove(purchase);
    notifyListeners();
    _sync(() => remote!.deletePurchase(purchase.id));
    return purchase;
  }

  /// Sets what was really paid. A null [amount] removes the price.
  void updatePurchaseAmount(String purchaseId, double? amount) {
    if (amount != null && (amount < 0 || amount.isNaN || amount.isInfinite)) {
      throw ArgumentError('The amount cannot be negative');
    }
    final index = _purchases.indexWhere((p) => p.id == purchaseId);
    if (index == -1) {
      throw ArgumentError('Purchase $purchaseId not found');
    }
    final updated = amount == null
        ? _purchases[index].copyWith(clearAmount: true)
        : _purchases[index].copyWith(amount: amount);
    _purchases[index] = updated;
    notifyListeners();
    _sync(() => remote!.savePurchase(updated));
  }

  void deletePurchase(String purchaseId) {
    final index = _purchases.indexWhere((p) => p.id == purchaseId);
    if (index == -1) {
      return;
    }
    _purchases.removeAt(index);
    notifyListeners();
    _sync(() => remote!.deletePurchase(purchaseId));
  }

  // ---------------------------------------------------------------------------
  // Firestore
  // ---------------------------------------------------------------------------

  /// Loads the signed-in user's budget and purchases (after [clear]).
  void connect() {
    if (remote != null) {
      _loadRemote();
    }
  }

  /// Forgets the previous user's data.
  void clear() {
    _budget = null;
    _purchases.clear();
    isLoading = false;
    notifyListeners();
  }

  Future<void> _loadRemote() async {
    isLoading = true;
    notifyListeners();
    try {
      final data = await remote!.load();
      // Keep a budget set on this phone while the data was loading.
      _budget ??= data.budget;
      for (final purchase in data.purchases) {
        if (purchaseById(purchase.id) == null) {
          _purchases.add(purchase);
        }
      }
      _purchases.sort((a, b) => a.date.compareTo(b.date));
    } catch (error) {
      debugPrint('Could not load the budget: $error');
    }
    isLoading = false;
    notifyListeners();
  }

  /// Runs a Firestore write without blocking the screen.
  void _sync(Future<void> Function() write) {
    if (remote == null) {
      return;
    }
    write().catchError(
      (Object error) => debugPrint('Could not save the budget: $error'),
    );
  }

  String _newId() =>
      'purchase-${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';
}
