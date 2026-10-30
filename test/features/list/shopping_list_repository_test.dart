import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/list/data/shopping_list_repository.dart';
import 'package:foodsaver/features/list/domain/shopping_category.dart';

void main() {
  late ShoppingListRepository repository;
  late String listId;

  ShoppingCategory category(String name) => repository.categoryNamed(name)!;

  setUp(() {
    repository = ShoppingListRepository(seed: false);
    listId = repository.createList('Weekly').id;
  });

  group('lists', () {
    test('createList selects the new list', () {
      final party = repository.createList('Party');

      expect(repository.lists, hasLength(2));
      expect(repository.selectedList?.id, party.id);
    });

    test('createList rejects empty and duplicate names', () {
      expect(() => repository.createList('   '), throwsArgumentError);
      expect(() => repository.createList('weekly'), throwsArgumentError);
    });

    test('renameList and deleteList update the selection', () {
      final party = repository.createList('Party');
      repository.renameList(party.id, 'Birthday');
      expect(repository.listById(party.id)?.name, 'Birthday');

      repository.deleteList(party.id);
      expect(repository.lists, hasLength(1));
      expect(repository.selectedList?.id, listId);

      repository.deleteList(listId);
      expect(repository.selectedList, isNull);
    });
  });

  group('items', () {
    test('addItem adds a pending item and notifies listeners', () {
      var notifications = 0;
      repository.addListener(() => notifications++);

      final item = repository.addItem(
        listId,
        name: '  Apples ',
        category: category('Fruits'),
        quantity: 3,
        unit: 'kg',
      );

      expect(item.name, 'Apples');
      expect(item.isBought, isFalse);
      expect(repository.listById(listId)!.remainingCount, 1);
      expect(notifications, 1);
    });

    test('adding the same item merges quantities instead of duplicating', () {
      repository.addItem(listId, name: 'Milk', category: category('Dairy'));
      final merged = repository.addItem(
        listId,
        name: 'milk',
        category: category('Dairy'),
        quantity: 2,
      );

      expect(repository.listById(listId)!.items, hasLength(1));
      expect(merged.quantity, 3);
    });

    test('re-adding a bought item moves it back to the to-buy section', () {
      final item = repository.addItem(
        listId,
        name: 'Eggs',
        category: category('Dairy'),
      );
      repository.toggleBought(listId, item.id);

      final readded = repository.addItem(
        listId,
        name: 'Eggs',
        category: category('Dairy'),
        quantity: 6,
      );

      expect(readded.isBought, isFalse);
      expect(readded.boughtAt, isNull);
      expect(readded.quantity, 6);
    });

    test('addItem validates name and quantity', () {
      expect(
        () =>
            repository.addItem(listId, name: ' ', category: category('Dairy')),
        throwsArgumentError,
      );
      expect(
        () => repository.addItem(
          listId,
          name: 'Milk',
          category: category('Dairy'),
          quantity: 0,
        ),
        throwsArgumentError,
      );
    });

    test('toggleBought updates counters and progress automatically', () {
      final a = repository.addItem(
        listId,
        name: 'A',
        category: category('Pantry'),
      );
      repository.addItem(listId, name: 'B', category: category('Pantry'));

      repository.toggleBought(listId, a.id);
      final list = repository.listById(listId)!;

      expect(list.boughtCount, 1);
      expect(list.remainingCount, 1);
      expect(list.progress, 0.5);
      expect(list.boughtItems.single.boughtAt, isNotNull);

      repository.toggleBought(listId, a.id);
      expect(list.boughtCount, 0);
      expect(list.items.first.boughtAt, isNull);
    });

    test('updateItem edits an existing item', () {
      final item = repository.addItem(
        listId,
        name: 'Bread',
        category: category('Bakery'),
      );

      repository.updateItem(
        listId,
        item.copyWith(name: 'Baguette', quantity: 2, note: ' fresh '),
      );

      final updated = repository.listById(listId)!.items.single;
      expect(updated.name, 'Baguette');
      expect(updated.quantity, 2);
      expect(updated.note, 'fresh');
    });

    test('removeItem and restoreItem support undo', () {
      repository.addItem(listId, name: 'A', category: category('Pantry'));
      final b = repository.addItem(
        listId,
        name: 'B',
        category: category('Pantry'),
      );
      repository.addItem(listId, name: 'C', category: category('Pantry'));

      final index = repository.removeItem(listId, b.id);
      expect(index, 1);
      expect(repository.listById(listId)!.items, hasLength(2));

      repository.restoreItem(listId, b, index);
      expect(repository.listById(listId)!.items.map((item) => item.name), [
        'A',
        'B',
        'C',
      ]);
    });

    test('markAllBought and clearBought', () {
      repository.addItem(listId, name: 'A', category: category('Pantry'));
      repository.addItem(listId, name: 'B', category: category('Pantry'));

      repository.markAllBought(listId);
      final list = repository.listById(listId)!;
      expect(list.isCompleted, isTrue);

      final removed = repository.clearBought(listId);
      expect(removed, hasLength(2));
      expect(list.items, isEmpty);
    });
  });

  group('categories', () {
    test('addCategory creates a custom category before "Other"', () {
      final snacks = repository.addCategory('Snacks');

      expect(snacks.isCustom, isTrue);
      expect(repository.categories.last, otherShoppingCategory);
      expect(repository.hasCategoryNamed('snacks'), isTrue);
      expect(() => repository.addCategory('SNACKS'), throwsArgumentError);
    });

    test('removeCategory moves its items to "Other"', () {
      final snacks = repository.addCategory('Snacks');
      repository.addItem(listId, name: 'Chips', category: snacks);

      repository.removeCategory(snacks);

      expect(repository.hasCategoryNamed('Snacks'), isFalse);
      expect(
        repository.listById(listId)!.items.single.category,
        otherShoppingCategory,
      );
    });

    test('default categories cannot be removed', () {
      expect(
        () => repository.removeCategory(category('Dairy')),
        throwsArgumentError,
      );
    });
  });
}
