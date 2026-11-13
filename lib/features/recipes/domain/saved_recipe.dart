/// A recipe the user added to their favorites.
///
/// Only the recipe id is stored: the recipe itself comes from the app's
/// recipe book (`allRecipes`).
class SavedRecipe {
  const SavedRecipe({required this.recipeId, required this.savedAt});

  final String recipeId;
  final DateTime savedAt;

  @override
  bool operator ==(Object other) =>
      other is SavedRecipe &&
      other.recipeId == recipeId &&
      other.savedAt == savedAt;

  @override
  int get hashCode => Object.hash(recipeId, savedAt);
}
