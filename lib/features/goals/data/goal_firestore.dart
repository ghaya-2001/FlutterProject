import 'package:cloud_firestore/cloud_firestore.dart';

import '../../fridge/domain/food_category.dart';
import '../domain/donation_goal.dart';

/// Reads and writes donation goals in Firestore.
///
/// Structure:
/// ```
/// donation_goals/{goalId}   restaurantId, restaurantName, title, foodName,
///                           category, target, unit, description, deadline,
///                           createdAt, closed, contributions: [...]
/// ```
/// Goals are shared (top-level) because every user must see the goals of
/// every restaurant. The progress is not stored: it is the sum of the
/// contributions, and a contribution is added with `arrayUnion`, so two
/// donors giving at the same moment both count.
class GoalFirestore {
  GoalFirestore({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _goals =>
      _db.collection('donation_goals');

  /// Every goal, sent again each time one of them changes (a donor gave on
  /// another phone), so the progress bars move in real time.
  Stream<List<Map<String, dynamic>>> watchAll() {
    return _goals.snapshots().map(
      (snapshot) => [
        for (final doc in snapshot.docs) {...doc.data(), 'id': doc.id},
      ],
    );
  }

  Future<void> create(DonationGoal goal) =>
      _goals.doc(goal.id).set(donationGoalToMap(goal));

  Future<void> addContribution(String goalId, GoalContribution contribution) {
    return _goals.doc(goalId).update({
      'contributions': FieldValue.arrayUnion([
        goalContributionToMap(contribution),
      ]),
    });
  }

  Future<void> close(String goalId) =>
      _goals.doc(goalId).update({'closed': true});

  Future<void> delete(String goalId) => _goals.doc(goalId).delete();
}

// -----------------------------------------------------------------------------
// Conversion between the models and Firestore maps
// -----------------------------------------------------------------------------

Map<String, dynamic> donationGoalToMap(DonationGoal goal) {
  return {
    'restaurantId': goal.restaurantId,
    'restaurantName': goal.restaurantName,
    'title': goal.title,
    'foodName': goal.foodName,
    // Only the name is stored: icon and color come from the app.
    'category': goal.category.name,
    'target': goal.target,
    'unit': goal.unit,
    'description': goal.description,
    'deadline': goal.deadline == null
        ? null
        : Timestamp.fromDate(goal.deadline!),
    'createdAt': Timestamp.fromDate(goal.createdAt),
    'closed': goal.closed,
    'contributions': [
      for (final contribution in goal.contributions)
        goalContributionToMap(contribution),
    ],
  };
}

Map<String, dynamic> goalContributionToMap(GoalContribution contribution) {
  return {
    'id': contribution.id,
    'donorId': contribution.donorId,
    'donorName': contribution.donorName,
    'quantity': contribution.quantity,
    'createdAt': Timestamp.fromDate(contribution.createdAt),
    'fromFridge': contribution.fromFridge,
  };
}

/// [categoryFor] turns a stored category name back into a fridge category.
DonationGoal donationGoalFromMap(
  Map<String, dynamic> map,
  FoodCategory Function(String name) categoryFor,
) {
  return DonationGoal(
    id: map['id'] as String,
    restaurantId: map['restaurantId'] as String? ?? '',
    restaurantName: map['restaurantName'] as String? ?? '',
    title: map['title'] as String? ?? '',
    foodName: map['foodName'] as String? ?? '',
    category: categoryFor(map['category'] as String? ?? 'Other'),
    target: (map['target'] as num? ?? 0).toDouble(),
    unit: map['unit'] as String? ?? 'pcs',
    description: map['description'] as String? ?? '',
    deadline: _date(map['deadline']),
    createdAt: _date(map['createdAt']) ?? DateTime.now(),
    closed: map['closed'] as bool? ?? false,
    contributions: [
      for (final contribution in map['contributions'] as List? ?? const [])
        goalContributionFromMap(Map<String, dynamic>.from(contribution as Map)),
    ],
  );
}

GoalContribution goalContributionFromMap(Map<String, dynamic> map) {
  return GoalContribution(
    id: map['id'] as String? ?? '',
    donorId: map['donorId'] as String? ?? '',
    donorName: map['donorName'] as String? ?? '',
    quantity: (map['quantity'] as num? ?? 0).toDouble(),
    createdAt: _date(map['createdAt']) ?? DateTime.now(),
    fromFridge: map['fromFridge'] as bool? ?? false,
  );
}

DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;
