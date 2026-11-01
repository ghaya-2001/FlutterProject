import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/fridge/data/fridge_firestore.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/fridge/domain/food_category.dart';
import 'package:foodsaver/features/fridge/domain/food_item.dart';
import 'package:foodsaver/features/fridge/domain/fridge_event.dart';

/// In-memory stand-in for Firestore that records every write and lets the
/// test push snapshots, as if another phone had changed the fridge.
class FakeFridgeFirestore implements FridgeFirestore {
  FakeFridgeFirestore({this.categories = const [], this.events = const []});

  final List<String> categories;
  final List<Map<String, dynamic>> events;
  final snapshots = StreamController<List<Map<String, dynamic>>>();

  final saved = <String, FoodItem>{};
  final deleted = <String>[];
  final batches = <List<FoodItem>>[];
  final addedEvents = <FridgeEvent>[];
  List<String>? savedCategories;

  @override
  String get userId => 'test-user';

  @override
  Future<List<String>> loadCustomCategories() async => categories;

  @override
  Future<List<Map<String, dynamic>>> loadHistory() async => events;

  @override
  Stream<List<Map<String, dynamic>>> watchItems() => snapshots.stream;

  @override
  Future<void> saveItem(FoodItem item) async => saved[item.id] = item;

  @override
  Future<void> saveItems(List<FoodItem> items) async => batches.add(items);

  @override
  Future<void> deleteItem(String itemId) async => deleted.add(itemId);

  @override
  Future<void> saveCustomCategories(List<String> names) async =>
      savedCategories = names;

  @override
  Future<void> addEvent(FridgeEvent event) async => addedEvents.add(event);
}

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  final dairy = defaultFoodCategories.firstWhere((c) => c.name == 'Dairy');

  group('mapping', () {
    test('food item round trip', () {
      final item = FoodItem(
        id: 'food-1',
        name: 'Yogurt',
        category: dairy,
        quantity: 2.5,
        unit: 'pcs',
        expiryDate: DateTime(2026, 10, 30),
        addedAt: today,
        note: 'greek',
      );

      final map = {...foodItemToMap(item), 'id': item.id};
      expect(map['category'], 'Dairy');
      expect(map['expiryDate'], isA<Timestamp>());

      final back = foodItemFromMap(map, (_) => dairy);
      expect(back.id, 'food-1');
      expect(back.name, 'Yogurt');
      expect(back.category, dairy);
      expect(back.quantity, 2.5);
      expect(back.unit, 'pcs');
      expect(back.expiryDate, DateTime(2026, 10, 30));
      expect(back.addedAt, today);
      expect(back.note, 'greek');
    });

    test('event round trip', () {
      final event = FridgeEvent(
        id: 'event-1',
        type: FridgeEventType.wasted,
        foodName: 'Milk',
        category: dairy,
        quantity: 1,
        unit: 'L',
        at: today,
      );
      final back = fridgeEventFromMap({
        ...fridgeEventToMap(event),
        'id': event.id,
      }, (_) => dairy);
      expect(back.type, FridgeEventType.wasted);
      expect(back.foodName, 'Milk');
      expect(back.quantity, 1);
      expect(back.unit, 'L');
      expect(back.at, today);
    });

    test('missing fields fall back to defaults', () {
      final item = foodItemFromMap({'id': 'x'}, (_) => otherFoodCategory);
      expect(item.name, '');
      expect(item.quantity, 0);
      expect(item.unit, 'pcs');
      expect(item.category, otherFoodCategory);
    });
  });

  group('repository with Firestore', () {
    late FakeFridgeFirestore remote;
    late FridgeRepository repository;

    Future<void> connect({
      List<String> categories = const [],
      List<Map<String, dynamic>> events = const [],
    }) async {
      remote = FakeFridgeFirestore(categories: categories, events: events);
      repository = FridgeRepository(clock: () => today, remote: remote);
      await pumpEventQueue();
    }

    tearDown(() => remote.snapshots.close());

    test('does not seed and waits for the first snapshot', () async {
      await connect();
      expect(repository.isSynced, isTrue);
      expect(repository.isLoading, isTrue);
      expect(repository.totalCount, 0);

      remote.snapshots.add([]);
      await pumpEventQueue();
      expect(repository.isLoading, isFalse);
    });

    test('loads custom categories and history', () async {
      await connect(
        categories: ['Snacks'],
        events: [
          fridgeEventToMap(
            FridgeEvent(
              id: 'event-1',
              type: FridgeEventType.consumed,
              foodName: 'Chips',
              category: dairy,
              quantity: 1,
              unit: 'pack',
              at: today,
            ),
          )..['id'] = 'event-1',
        ],
      );
      expect(repository.categoryNamed('Snacks')?.isCustom, isTrue);
      expect(repository.history.single.foodName, 'Chips');
    });

    test('real-time snapshot replaces the stock', () async {
      await connect();
      final item = FoodItem(
        id: 'food-remote',
        name: 'Butter',
        category: dairy,
        quantity: 1,
        unit: 'pcs',
        expiryDate: DateTime(2026, 11, 2),
        addedAt: today,
      );
      var notifications = 0;
      repository.addListener(() => notifications++);

      remote.snapshots.add([
        {...foodItemToMap(item), 'id': item.id},
      ]);
      await pumpEventQueue();

      expect(repository.itemById('food-remote')?.name, 'Butter');
      expect(notifications, 1);

      remote.snapshots.add([]);
      await pumpEventQueue();
      expect(repository.totalCount, 0);
    });

    test('unknown category from another phone becomes custom', () async {
      await connect();
      final item = FoodItem(
        id: 'food-1',
        name: 'Hummus',
        category: const FoodCategory(
          name: 'Spreads',
          icon: Icons.label_rounded,
          color: Colors.amber,
        ),
        quantity: 1,
        unit: 'pcs',
        expiryDate: DateTime(2026, 11, 2),
        addedAt: today,
      );
      remote.snapshots.add([
        {...foodItemToMap(item), 'id': item.id},
      ]);
      await pumpEventQueue();
      expect(repository.categoryNamed('Spreads')?.isCustom, isTrue);
      expect(repository.itemById('food-1')!.category.name, 'Spreads');
    });

    test('every change is written to Firestore', () async {
      await connect();
      final item = repository.addFood(
        name: 'Milk',
        category: dairy,
        quantity: 2,
        unit: 'L',
        expiryDate: DateTime(2026, 10, 28),
      );
      await pumpEventQueue();
      expect(remote.saved[item.id]?.name, 'Milk');

      repository.consume(item.id, 0.5);
      await pumpEventQueue();
      expect(remote.saved[item.id]?.quantity, 1.5);
      expect(remote.addedEvents.single.type, FridgeEventType.consumed);

      repository.throwAway(item.id);
      await pumpEventQueue();
      expect(remote.deleted, [item.id]);
      expect(remote.addedEvents.last.type, FridgeEventType.wasted);
      expect(remote.addedEvents.last.quantity, 1.5);
    });

    test('custom categories are saved, moved foods in one batch', () async {
      await connect();
      final snacks = repository.addCategory('Snacks');
      expect(remote.savedCategories, ['Snacks']);

      final chips = repository.addFood(
        name: 'Chips',
        category: snacks,
        quantity: 1,
        unit: 'pack',
        expiryDate: DateTime(2026, 12, 1),
      );
      repository.removeCategory(snacks);
      await pumpEventQueue();

      expect(remote.savedCategories, isEmpty);
      expect(remote.batches.single.single.id, chips.id);
      expect(remote.batches.single.single.category, otherFoodCategory);
    });
  });
}
