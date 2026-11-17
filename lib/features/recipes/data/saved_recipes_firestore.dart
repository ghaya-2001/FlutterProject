// ignore_for_file: prefer_initializing_formals (private field, named parameter)
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/session/current_user.dart';
import '../domain/saved_recipe.dart';

/// Reads and writes the user's favorite recipes in Firestore.
///
/// Structure:
/// ```
/// users/{userId}/saved_recipes/{recipeId}   savedAt
/// ```
/// The document id is the recipe id, so a recipe can only be saved once.
class SavedRecipesFirestore {
  SavedRecipesFirestore({FirebaseFirestore? firestore, String? userId})
    : _db = firestore ?? FirebaseFirestore.instance,
      _userId = userId;

  static const collection = 'saved_recipes';

  final FirebaseFirestore _db;
  final String? _userId;

  /// The signed-in user, unless a fixed id was given (tests).
  String get userId => _userId ?? CurrentUser.uid;

  CollectionReference<Map<String, dynamic>> get _saved =>
      _db.collection('users').doc(userId).collection(collection);

  /// Favorites, newest first.
  Future<List<SavedRecipe>> load() async {
    final snapshot = await _saved.orderBy('savedAt', descending: true).get();
    return [
      for (final doc in snapshot.docs)
        savedRecipeFromMap({...doc.data(), 'recipeId': doc.id}),
    ];
  }

  Future<void> save(SavedRecipe saved) =>
      _saved.doc(saved.recipeId).set(savedRecipeToMap(saved));

  Future<void> delete(String recipeId) => _saved.doc(recipeId).delete();
}

Map<String, dynamic> savedRecipeToMap(SavedRecipe saved) => {
  'savedAt': Timestamp.fromDate(saved.savedAt),
};

SavedRecipe savedRecipeFromMap(Map<String, dynamic> map) {
  final savedAt = map['savedAt'];
  return SavedRecipe(
    recipeId: map['recipeId'] as String,
    savedAt: savedAt is Timestamp
        ? savedAt.toDate()
        : (savedAt is DateTime ? savedAt : DateTime.now()),
  );
}
