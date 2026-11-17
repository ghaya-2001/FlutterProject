import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/donations/data/donation_repository.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/notifications/data/notification_repository.dart';
import 'package:foodsaver/features/recipes/data/saved_recipes_repository.dart';
import 'package:foodsaver/features/statistics/presentation/activity_history_screen.dart';
import 'package:foodsaver/features/statistics/presentation/statistics_screen.dart';

void main() {
  final today = DateTime(2026, 10, 24, 10, 30);
  late FridgeRepository fridge;
  late DonationRepository donations;
  late SavedRecipesRepository saved;

  setUp(() {
    fridge = FridgeRepository(clock: () => today);
    donations = DonationRepository(
      seed: false,
      fridge: fridge,
      notifications: NotificationRepository(fridge: fridge),
    );
    saved = SavedRecipesRepository(clock: () => today);
  });

  String idOf(String name) =>
      fridge.items.firstWhere((item) => item.name == name).id;

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
  }

  Widget statistics() => StatisticsScreen(
    fridge: fridge,
    donations: donations,
    savedRecipes: saved,
  );

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  testWidgets('empty history shows zeros and an empty activity', (
    tester,
  ) async {
    await pump(tester, statistics());
    expect(textOf(tester, 'stats-meals'), '0 meals saved');
    expect(find.text('—'), findsOneWidget); // no score yet
    expect(find.textContaining('No activity yet'), findsOneWidget);
  });

  testWidgets('eating and throwing away update the statistics', (tester) async {
    fridge.consume(idOf('Tomatoes'), 1); // 1 kg vegetables
    fridge.throwAway(idOf('Yogurt')); // 4 pcs dairy = 0.8 kg
    saved.save('pancakes');

    await pump(tester, statistics());
    expect(textOf(tester, 'stats-meals'), '3 meals saved'); // 1 / 0.4 = 2.5
    expect(find.text('1 kg'), findsOneWidget);
    expect(find.text('0.8 kg'), findsOneWidget); // CO₂ avoided: 1 × 0.8
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Ate Tomatoes'), findsOneWidget);
    expect(find.text('Threw away Yogurt'), findsOneWidget);
    expect(find.text('Saved Pancakes'), findsOneWidget);
    expect(textOf(tester, 'stats-breakdown-eaten'), '1');
  });

  testWidgets('switching period and opening the history', (tester) async {
    fridge.consume(idOf('Milk'), 0.5);
    await pump(tester, statistics());

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(find.text('All time'), findsWidgets);

    await tester.ensureVisible(find.byKey(const ValueKey('stats-see-all')));
    await tester.tap(find.byKey(const ValueKey('stats-see-all')));
    await tester.pumpAndSettle();
    expect(find.text('Activity history'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Ate Milk'), findsOneWidget);
  });

  testWidgets('history filters by type', (tester) async {
    fridge.consume(idOf('Milk'), 0.5);
    fridge.throwAway(idOf('Yogurt'));
    await pump(
      tester,
      ActivityHistoryScreen(
        fridge: fridge,
        donations: donations,
        savedRecipes: saved,
      ),
    );
    expect(find.text('Ate Milk'), findsOneWidget);
    expect(find.text('Threw away Yogurt'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('activity-filter-wasted')));
    await tester.pumpAndSettle();
    expect(find.text('Ate Milk'), findsNothing);
    expect(find.text('Threw away Yogurt'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('activity-filter-recipes')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet.'), findsOneWidget);
  });

  test('dayLabel', () {
    expect(dayLabel(today, today), 'Today');
    expect(
      dayLabel(today.subtract(const Duration(days: 1)), today),
      'Yesterday',
    );
    expect(dayLabel(DateTime(2026, 10, 1), today), '1 Oct 2026');
  });
}
