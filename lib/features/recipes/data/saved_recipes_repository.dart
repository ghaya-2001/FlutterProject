import 'package:flutter/foundation.dart';

import '../../../core/firebase/firebase_setup.dart';
import '../domain/saved_recipe.dart';
import 'saved_recipes_firestore.dart';

/// The user's favorite recipes (Membre 5).
///
/// Kept in memory for the screens; when [remote] is set (Firebase
/// connected), every change is also saved in Firestore in the background.
class SavedRecipesRepository extends ChangeNotifier {
  /// [autoConnect] false waits for [connect] (the app-wide instance, bound
  /// to the signed-in user by `SessionBinder`).
  SavedRecipesRepository({
    this.remote,
    DateTime Function()? clock,
    bool autoConnect = true,
  }) : _clock = clock ?? DateTime.now {
    if (remote != null && autoConnect) {
      _loadRemote();
    }
  }

  static final SavedRecipesRepository instance = SavedRecipesRepository(
    remote: FirebaseSetup.isReady ? SavedRecipesFirestore() : null,
    autoConnect: false,
  );

  /// Firestore storage; null in tests or when Firebase is not configured.
  final SavedRecipesFirestore? remote;

  final DateTime Function() _clock;

  /// Newest first.
  final List<SavedRecipe> _saved = [];

  DateTime get now => _clock();

  /// Favorites, newest first.
  List<SavedRecipe> get saved => List.unmodifiable(_saved);

  List<String> get savedIds => [for (final s in _saved) s.recipeId];

  int get count => _saved.length;

  bool isSaved(String recipeId) => _saved.any((s) => s.recipeId == recipeId);

  /// Adds [recipeId] to the favorites (does nothing if already there).
  void save(String recipeId) {
    if (isSaved(recipeId)) {
      return;
    }
    final saved = SavedRecipe(recipeId: recipeId, savedAt: now);
    _saved.insert(0, saved);
    notifyListeners();
    _sync(() => remote!.save(saved));
  }

  /// Removes [recipeId] and returns it, so the screen can offer Undo.
  SavedRecipe? remove(String recipeId) {
    final index = _saved.indexWhere((s) => s.recipeId == recipeId);
    if (index == -1) {
      return null;
    }
    final removed = _saved.removeAt(index);
    notifyListeners();
    _sync(() => remote!.delete(recipeId));
    return removed;
  }

  /// Puts back a favorite removed by [remove], at its original date.
  void restore(SavedRecipe saved) {
    if (isSaved(saved.recipeId)) {
      return;
    }
    _saved
      ..add(saved)
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    notifyListeners();
    _sync(() => remote!.save(saved));
  }

  /// Saves or removes [recipeId]; returns true when it is now saved.
  bool toggle(String recipeId) {
    if (isSaved(recipeId)) {
      remove(recipeId);
      return false;
    }
    save(recipeId);
    return true;
  }

  /// Loads the signed-in user's favorites (after [clear]).
  void connect() {
    if (remote != null) {
      _loadRemote();
    }
  }

  /// Forgets the previous user's favorites.
  void clear() {
    _saved.clear();
    notifyListeners();
  }

  Future<void> _loadRemote() async {
    try {
      final loaded = await remote!.load();
      for (final saved in loaded) {
        if (!isSaved(saved.recipeId)) {
          _saved.add(saved);
        }
      }
      _saved.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      notifyListeners();
    } catch (error) {
      debugPrint('Could not load saved recipes: $error');
    }
  }

  /// Runs a Firestore write without blocking the screen.
  void _sync(Future<void> Function() write) {
    if (remote == null) {
      return;
    }
    write().catchError(
      (Object error) => debugPrint('Could not save recipe: $error'),
    );
  }
}
