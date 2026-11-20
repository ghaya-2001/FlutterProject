// ignore_for_file: prefer_initializing_formals (private field, named parameter)
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/session/current_user.dart';
import '../domain/budget.dart';
import '../domain/purchase.dart';

/// What is stored in Firestore for the budget.
class BudgetData {
  const BudgetData({required this.budget, required this.purchases});

  final ShoppingBudget? budget;
  final List<Purchase> purchases;
}

/// Reads and writes the food budget and the purchases in Firestore.
///
/// Structure:
/// ```
/// users/{userId}                       shoppingBudget: {amount, period}
/// users/{userId}/purchases/{id}        itemId, listId, name, category,
///                                      quantity, unit, amount, date
/// ```
/// Purchases are separate documents (not inside the list) so the spending
/// history survives "Clear bought items" and deleted lists.
class BudgetFirestore {
  BudgetFirestore({FirebaseFirestore? firestore, String? userId})
    : _db = firestore ?? FirebaseFirestore.instance,
      _userId = userId;

  final FirebaseFirestore _db;
  final String? _userId;

  /// The signed-in user, unless a fixed id was given (tests).
  String get userId => _userId ?? CurrentUser.uid;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(userId);

  CollectionReference<Map<String, dynamic>> get _purchases =>
      _user.collection('purchases');

  Future<BudgetData> load() async {
    final user = await _user.get();
    final purchases = await _purchases.orderBy('date').get();
    return BudgetData(
      budget: budgetFromMap(user.data()?['shoppingBudget']),
      purchases: [
        for (final doc in purchases.docs)
          purchaseFromMap({...doc.data(), 'id': doc.id}),
      ],
    );
  }

  /// Saves the budget, or removes it when [budget] is null.
  Future<void> saveBudget(ShoppingBudget? budget) {
    return _user.set({
      'shoppingBudget': budget == null
          ? FieldValue.delete()
          : budgetToMap(budget),
    }, SetOptions(merge: true));
  }

  Future<void> savePurchase(Purchase purchase) =>
      _purchases.doc(purchase.id).set(purchaseToMap(purchase));

  Future<void> deletePurchase(String purchaseId) =>
      _purchases.doc(purchaseId).delete();
}

// -----------------------------------------------------------------------------
// Conversion between the models and Firestore maps
// -----------------------------------------------------------------------------

Map<String, dynamic> budgetToMap(ShoppingBudget budget) {
  return {'amount': budget.amount, 'period': budget.period.name};
}

/// Returns null when nothing (or something unreadable) is stored.
ShoppingBudget? budgetFromMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  final amount = (value['amount'] as num?)?.toDouble();
  if (amount == null || amount <= 0) {
    return null;
  }
  return ShoppingBudget(
    amount: amount,
    period: value['period'] == BudgetPeriod.weekly.name
        ? BudgetPeriod.weekly
        : BudgetPeriod.monthly,
  );
}

Map<String, dynamic> purchaseToMap(Purchase purchase) {
  return {
    'itemId': purchase.itemId,
    'listId': purchase.listId,
    'name': purchase.name,
    // Only the name is stored: icon and color come from the app.
    'category': purchase.categoryName,
    'quantity': purchase.quantity,
    'unit': purchase.unit,
    'amount': purchase.amount,
    'date': Timestamp.fromDate(purchase.date),
  };
}

Purchase purchaseFromMap(Map<String, dynamic> map) {
  final date = map['date'];
  return Purchase(
    id: map['id'] as String,
    itemId: map['itemId'] as String? ?? '',
    listId: map['listId'] as String? ?? '',
    name: map['name'] as String? ?? '',
    categoryName: map['category'] as String? ?? 'Other',
    quantity: (map['quantity'] as num? ?? 1).toInt(),
    unit: map['unit'] as String? ?? 'pcs',
    amount: (map['amount'] as num?)?.toDouble(),
    date: date is Timestamp ? date.toDate() : DateTime.now(),
  );
}
