import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/list/domain/budget.dart';
import 'package:foodsaver/features/list/domain/purchase.dart';
import 'package:foodsaver/features/list/domain/shopping_category.dart';
import 'package:foodsaver/features/list/domain/shopping_item.dart';
import 'package:foodsaver/features/list/domain/spending_analysis.dart';

void main() {
  // Monday 16 Nov 2026, 10:00.
  final now = DateTime(2026, 11, 16, 10);
  var counter = 0;

  Purchase purchase(String category, double? amount, DateTime date) {
    counter++;
    return Purchase(
      id: 'p$counter',
      itemId: 'item$counter',
      listId: 'list',
      name: '$category item $counter',
      categoryName: category,
      quantity: 1,
      unit: 'pcs',
      amount: amount,
      date: date,
    );
  }

  ShoppingItem toBuy(double? unitPrice, {int quantity = 1}) => ShoppingItem(
    id: 'todo${counter++}',
    name: 'Item',
    category: otherShoppingCategory,
    createdAt: now,
    quantity: quantity,
    estimatedPrice: unitPrice,
  );

  final thisMonth = DateTime(2026, 11, 5);
  final lastMonth = DateTime(2026, 10, 20);

  group('periods', () {
    test('a month runs from the 1st to the 1st of the next month', () {
      final range = periodRange(BudgetPeriod.monthly, now);
      expect(range.start, DateTime(2026, 11));
      expect(range.end, DateTime(2026, 12));
      expect(range.contains(DateTime(2026, 11, 30, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 12)), isFalse);
    });

    test('a week runs from Monday to Sunday', () {
      final sunday = DateTime(2026, 11, 22, 20);
      final range = periodRange(BudgetPeriod.weekly, sunday);
      expect(range.start, DateTime(2026, 11, 16));
      expect(range.end, DateTime(2026, 11, 23));
      expect(
        previousPeriodRange(BudgetPeriod.weekly, sunday).start,
        DateTime(2026, 11, 9),
      );
    });

    test('the previous month crosses the year', () {
      final range = previousPeriodRange(
        BudgetPeriod.monthly,
        DateTime(2027, 1, 10),
      );
      expect(range.start, DateTime(2026, 12));
      expect(range.end, DateTime(2027, 1));
    });
  });

  group('parsePrice', () {
    test('reads dots and commas, empty means no price', () {
      expect(parsePrice('2.5'), 2.5);
      expect(parsePrice(' 2,5 '), 2.5);
      expect(parsePrice(''), isNull);
    });

    test('rejects text and negative numbers', () {
      expect(() => parsePrice('abc'), throwsFormatException);
      expect(() => parsePrice('-3'), throwsFormatException);
    });
  });

  group('analyzeSpending', () {
    // Prices like the professor's example, entered by the "user" here.
    final purchases = [
      purchase('Vegetables', 30, thisMonth),
      purchase('Meat & Fish', 60, thisMonth),
      purchase('Meat & Fish', 40, thisMonth),
      purchase('Dairy', 25, thisMonth),
      purchase('Fruits', 45, thisMonth),
      purchase('Snacks', 50, thisMonth),
      purchase('Snacks', null, thisMonth),
      purchase('Snacks', 30, lastMonth),
    ];
    const budget = ShoppingBudget(amount: 400, period: BudgetPeriod.monthly);

    late SpendingReport report;
    setUp(() {
      report = analyzeSpending(
        purchases: purchases,
        itemsToBuy: [toBuy(10, quantity: 2), toBuy(null)],
        now: now,
        budget: budget,
      );
    });

    test('totals only the priced purchases of the current month', () {
      expect(report.totalSpent, closeTo(250, 1e-9));
      expect(report.purchases, hasLength(7));
      expect(report.missingPriceCount, 1);
    });

    test('groups by category, highest first, with shares', () {
      expect(report.byCategory.map((c) => c.category), [
        'Meat & Fish',
        'Snacks',
        'Fruits',
        'Vegetables',
        'Dairy',
      ]);
      final meat = report.highest!;
      expect(meat.amount, 100);
      expect(meat.shareOfSpending, closeTo(0.4, 1e-9));
      expect(meat.shareOfBudget, closeTo(0.25, 1e-9));
      expect(meat.purchaseCount, 2);
      expect(report.lowest!.category, 'Dairy');
    });

    test('budget, remaining, usage and projection', () {
      expect(report.remaining, 150);
      expect(report.usage, closeTo(0.625, 1e-9));
      expect(report.estimatedToBuy, 20);
      expect(report.itemsToBuyWithoutPrice, 1);
      expect(report.projectedSpent, 270);
      expect(report.isOverBudget, isFalse);
    });

    test('remembers last month for comparisons', () {
      expect(report.previousTotal, 30);
      expect(report.previousByCategory, {'Snacks': 30});
    });

    test('insights explain the spending in plain words', () {
      final texts = spendingInsights(report).map((i) => i.text).toList();
      expect(
        texts,
        contains(
          'Meat & Fish is your highest spending category this month: '
          '100.00 DT, 40% of your spending and 25% of your budget.',
        ),
      );
      expect(texts, contains('You have spent 63% of your budget this month.'));
      expect(texts, contains('You have 150.00 DT remaining.'));
      expect(
        texts,
        contains(
          'Your spending on Snacks is higher than last month (+20.00 DT).',
        ),
      );
      expect(
        texts,
        contains(
          'You spend the least on Dairy: 25.00 DT (10% of your spending).',
        ),
      );
      expect(texts.any((t) => t.startsWith('1 purchase has no price')), isTrue);
      expect(texts.any((t) => t.contains('1 item has no price yet')), isTrue);
    });
  });

  test('over budget is reported as a warning', () {
    final report = analyzeSpending(
      purchases: [purchase('Meat & Fish', 120, thisMonth)],
      itemsToBuy: const [],
      now: now,
      budget: const ShoppingBudget(amount: 100, period: BudgetPeriod.monthly),
    );
    expect(report.isOverBudget, isTrue);
    expect(report.remaining, -20);
    final over = spendingInsights(report)
        .firstWhere((i) => i.kind == InsightKind.overBudget);
    expect(over.text, 'You are 20.00 DT over your budget.');
    expect(over.isWarning, isTrue);
  });

  test('without purchases or budget, the insights say what to do', () {
    final report = analyzeSpending(
      purchases: const [],
      itemsToBuy: const [],
      now: now,
    );
    expect(report.byCategory, isEmpty);
    expect(report.highest, isNull);
    expect(report.usage, isNull);
    final kinds = spendingInsights(report).map((i) => i.kind);
    expect(kinds, containsAll([InsightKind.noData, InsightKind.noBudget]));
  });

  test('no comparison without data for the previous period', () {
    final report = analyzeSpending(
      purchases: [purchase('Snacks', 50, thisMonth)],
      itemsToBuy: const [],
      now: now,
    );
    expect(
      spendingInsights(report).map((i) => i.kind),
      isNot(contains(InsightKind.trend)),
    );
  });

  test('a weekly budget only counts this week', () {
    final report = analyzeSpending(
      purchases: [
        purchase('Dairy', 10, DateTime(2026, 11, 16, 8)),
        purchase('Dairy', 99, DateTime(2026, 11, 15, 20)),
      ],
      itemsToBuy: const [],
      now: now,
      budget: const ShoppingBudget(amount: 50, period: BudgetPeriod.weekly),
    );
    expect(report.totalSpent, 10);
    expect(report.previousTotal, 99);
  });
}
