import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/recipes/data/saved_recipes_firestore.dart';
import 'package:foodsaver/features/recipes/data/saved_recipes_repository.dart';
import 'package:foodsaver/features/recipes/domain/saved_recipe.dart';

/// In-memory stand-in for Firestore that records every write.
class FakeSavedRecipesFirestore implements SavedRecipesFirestore {
  FakeSavedRecipesFirestore([List<SavedRecipe>? stored])
    : stored = stored ?? [];

  final List<SavedRecipe> stored;
  final saved = <SavedRecipe>[];
  final deleted = <String>[];

  @override
  String get userId => 'test-user';

  @override
  Future<List<SavedRecipe>> load() async => List.of(stored);

  @override
  Future<void> save(SavedRecipe recipe) async => saved.add(recipe);

  @override
  Future<void> delete(String recipeId) async => deleted.add(recipeId);
}

void main() {
  var now = DateTime(2026, 11, 13, 9);
  DateTime clock() => now;

  setUp(() => now = DateTime(2026, 11, 13, 9));

  group('SavedRecipesRepository without Firebase', () {
    test('saves recipes once, newest first', () {
      final repository = SavedRecipesRepository(clock: clock);
      var notified = 0;
      repository.addListener(() => notified++);

      repository.save('shakshuka');
      now = now.add(const Duration(minutes: 5));
      repository.save('pancakes');
      repository.save('pancakes');

      expect(repository.savedIds, ['pancakes', 'shakshuka']);
      expect(repository.count, 2);
      expect(repository.isSaved('shakshuka'), isTrue);
      expect(repository.saved.first.savedAt, now);
      expect(notified, 2);
    });

    test('toggle adds then removes', () {
      final repository = SavedRecipesRepository(clock: clock);
      expect(repository.toggle('smoothie'), isTrue);
      expect(repository.isSaved('smoothie'), isTrue);
      expect(repository.toggle('smoothie'), isFalse);
      expect(repository.isSaved('smoothie'), isFalse);
    });

    test('remove returns the favorite and restore puts it back in order', () {
      final repository = SavedRecipesRepository(clock: clock);
      repository.save('a');
      now = now.add(const Duration(hours: 1));
      repository.save('b');
      now = now.add(const Duration(hours: 1));
      repository.save('c');

      final removed = repository.remove('b');
      expect(removed?.recipeId, 'b');
      expect(repository.savedIds, ['c', 'a']);
      expect(repository.remove('unknown'), isNull);

      repository.restore(removed!);
      expect(repository.savedIds, ['c', 'b', 'a']);
    });

    test('clear forgets the previous user favorites', () {
      final repository = SavedRecipesRepository(clock: clock)..save('a');
      repository.clear();
      expect(repository.saved, isEmpty);
    });
  });

  group('SavedRecipesRepository with Firestore', () {
    test('loads the stored favorites, newest first', () async {
      final remote = FakeSavedRecipesFirestore([
        SavedRecipe(recipeId: 'old', savedAt: DateTime(2026, 1, 1)),
        SavedRecipe(recipeId: 'new', savedAt: DateTime(2026, 6, 1)),
      ]);
      final repository = SavedRecipesRepository(remote: remote, clock: clock);
      await Future<void>.delayed(Duration.zero);
      expect(repository.savedIds, ['new', 'old']);
    });

    test('waits for connect when autoConnect is false', () async {
      final remote = FakeSavedRecipesFirestore([
        SavedRecipe(recipeId: 'a', savedAt: DateTime(2026)),
      ]);
      final repository = SavedRecipesRepository(
        remote: remote,
        clock: clock,
        autoConnect: false,
      );
      await Future<void>.delayed(Duration.zero);
      expect(repository.saved, isEmpty);

      repository.connect();
      await Future<void>.delayed(Duration.zero);
      expect(repository.savedIds, ['a']);
    });

    test('saves and deletes in the background', () async {
      final remote = FakeSavedRecipesFirestore();
      final repository = SavedRecipesRepository(remote: remote, clock: clock);
      repository.save('shakshuka');
      repository.toggle('shakshuka');
      await Future<void>.delayed(Duration.zero);

      expect(remote.saved.single.recipeId, 'shakshuka');
      expect(remote.saved.single.savedAt, now);
      expect(remote.deleted, ['shakshuka']);
    });
  });

  group('Firestore mapping', () {
    test('round-trips a saved recipe', () {
      final saved = SavedRecipe(
        recipeId: 'pancakes',
        savedAt: DateTime(2026, 11, 13, 9, 30),
      );
      final map = savedRecipeToMap(saved);
      expect(map['savedAt'], isA<Timestamp>());
      final back = savedRecipeFromMap({...map, 'recipeId': 'pancakes'});
      expect(back, saved);
    });
  });
}
