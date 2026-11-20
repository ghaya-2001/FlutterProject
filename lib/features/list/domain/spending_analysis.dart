import 'budget.dart';
import 'purchase.dart';
import 'shopping_item.dart';

/// Amounts closer than this are considered equal (half a millime).
const _epsilon = 0.0005;

/// How much was spent on one category during the period.
class CategorySpending {
  const CategorySpending({
    required this.category,
    required this.amount,
    required this.shareOfSpending,
    required this.purchaseCount,
    this.shareOfBudget,
  });

  final String category;
  final double amount;

  /// Part of the total spending, between 0 and 1.
  final double shareOfSpending;

  /// Part of the budget, or null when there is no budget.
  final double? shareOfBudget;

  /// Purchases with a price in this category.
  final int purchaseCount;
}

/// Everything the Budget screen shows, calculated by [analyzeSpending].
class SpendingReport {
  const SpendingReport({
    required this.period,
    required this.range,
    required this.purchases,
    required this.totalSpent,
    required this.byCategory,
    required this.missingPriceCount,
    required this.estimatedToBuy,
    required this.itemsToBuyWithoutPrice,
    required this.previousTotal,
    required this.previousByCategory,
    this.budget,
  });

  final ShoppingBudget? budget;
  final BudgetPeriod period;
  final DateRange range;

  /// Purchases of the period, newest first (with or without a price).
  final List<Purchase> purchases;

  /// Sum of the purchases that have a price.
  final double totalSpent;

  /// Spending per category, highest first.
  final List<CategorySpending> byCategory;

  /// Purchases of the period without a price (not counted in the totals).
  final int missingPriceCount;

  /// Estimated cost of the items still to buy on every list.
  final double estimatedToBuy;

  /// Items still to buy that have no estimated price.
  final int itemsToBuyWithoutPrice;

  /// Spending of the previous week or month, for comparisons.
  final double previousTotal;
  final Map<String, double> previousByCategory;

  bool get hasBudget => budget != null && budget!.amount > 0;

  /// Budget minus spending (negative when over budget), or null.
  double? get remaining => hasBudget ? budget!.amount - totalSpent : null;

  /// Spending divided by the budget (1.0 = 100%), or null.
  double? get usage => hasBudget ? totalSpent / budget!.amount : null;

  /// What will have been spent once every item still to buy is bought.
  double get projectedSpent => totalSpent + estimatedToBuy;

  double? get projectedUsage =>
      hasBudget ? projectedSpent / budget!.amount : null;

  bool get isOverBudget => hasBudget && totalSpent > budget!.amount + _epsilon;

  CategorySpending? get highest => byCategory.isEmpty ? null : byCategory.first;

  /// The cheapest category; null when fewer than two categories were bought.
  CategorySpending? get lowest =>
      byCategory.length < 2 ? null : byCategory.last;
}

/// Calculates spending for the week or month that contains [now].
///
/// [purchases] can contain the whole history: only those of the current
/// period are counted, and those of the previous period are used for the
/// comparison. [itemsToBuy] are the items not bought yet on every list.
/// Without a [budget], the analysis uses [defaultPeriod].
SpendingReport analyzeSpending({
  required Iterable<Purchase> purchases,
  required Iterable<ShoppingItem> itemsToBuy,
  required DateTime now,
  ShoppingBudget? budget,
  BudgetPeriod defaultPeriod = BudgetPeriod.monthly,
}) {
  final period = budget?.period ?? defaultPeriod;
  final range = periodRange(period, now);
  final previousRange = previousPeriodRange(period, now);

  final current = purchases.where((p) => range.contains(p.date)).toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  final totals = _totalsByCategory(current);
  final counts = <String, int>{};
  for (final purchase in current) {
    if (purchase.hasPrice) {
      counts[purchase.categoryName] = (counts[purchase.categoryName] ?? 0) + 1;
    }
  }
  final totalSpent = totals.values.fold(0.0, (sum, value) => sum + value);
  final hasBudget = budget != null && budget.amount > 0;

  final byCategory =
      [
        for (final entry in totals.entries)
          CategorySpending(
            category: entry.key,
            amount: entry.value,
            shareOfSpending: totalSpent > 0 ? entry.value / totalSpent : 0,
            shareOfBudget: hasBudget ? entry.value / budget.amount : null,
            purchaseCount: counts[entry.key] ?? 0,
          ),
      ]..sort((a, b) {
        final byAmount = b.amount.compareTo(a.amount);
        return byAmount != 0 ? byAmount : a.category.compareTo(b.category);
      });

  final previousByCategory = _totalsByCategory(
    purchases.where((p) => previousRange.contains(p.date)),
  );

  var estimatedToBuy = 0.0;
  var withoutPrice = 0;
  for (final item in itemsToBuy) {
    final total = item.estimatedTotal;
    if (total == null) {
      withoutPrice++;
    } else {
      estimatedToBuy += total;
    }
  }

  return SpendingReport(
    budget: budget,
    period: period,
    range: range,
    purchases: current,
    totalSpent: totalSpent,
    byCategory: byCategory,
    missingPriceCount: current.where((p) => !p.hasPrice).length,
    estimatedToBuy: estimatedToBuy,
    itemsToBuyWithoutPrice: withoutPrice,
    previousTotal: previousByCategory.values.fold(0.0, (sum, v) => sum + v),
    previousByCategory: previousByCategory,
  );
}

Map<String, double> _totalsByCategory(Iterable<Purchase> purchases) {
  final totals = <String, double>{};
  for (final purchase in purchases) {
    final amount = purchase.amount;
    if (amount != null) {
      totals[purchase.categoryName] =
          (totals[purchase.categoryName] ?? 0) + amount;
    }
  }
  return totals;
}

// -----------------------------------------------------------------------------
// Insights
// -----------------------------------------------------------------------------

enum InsightKind {
  noData,
  highestCategory,
  budgetUsage,
  remaining,
  overBudget,
  projection,
  trend,
  lowestCategory,
  missingPrice,
  noBudget,
}

/// One short sentence shown in the "Insights" card.
class SpendingInsight {
  const SpendingInsight(this.kind, this.text, {this.isWarning = false});

  final InsightKind kind;
  final String text;

  /// Shown in orange/red (over budget, close to the limit...).
  final bool isWarning;
}

/// Short, plain-language sentences about [report], most useful first.
List<SpendingInsight> spendingInsights(SpendingReport report) {
  final insights = <SpendingInsight>[];
  final when = periodName(report.period);
  final highest = report.highest;

  if (report.purchases.isEmpty) {
    insights.add(
      SpendingInsight(
        InsightKind.noData,
        'No purchases recorded $when yet. Tick items on your list as you '
        'buy them to track your spending.',
      ),
    );
  } else if (highest != null) {
    final ofBudget = highest.shareOfBudget == null
        ? ''
        : ' and ${formatPercent(highest.shareOfBudget!)} of your budget';
    insights.add(
      SpendingInsight(
        InsightKind.highestCategory,
        '${highest.category} is your highest spending category $when: '
        '${formatMoney(highest.amount)}, '
        '${formatPercent(highest.shareOfSpending)} of your spending$ofBudget.',
      ),
    );
  }

  if (report.hasBudget) {
    final usage = report.usage!;
    final remaining = report.remaining!;
    insights.add(
      SpendingInsight(
        InsightKind.budgetUsage,
        'You have spent ${formatPercent(usage)} of your budget $when.',
        isWarning: usage >= 0.8,
      ),
    );
    if (report.isOverBudget) {
      insights.add(
        SpendingInsight(
          InsightKind.overBudget,
          'You are ${formatMoney(-remaining)} over your budget.',
          isWarning: true,
        ),
      );
    } else {
      insights.add(
        SpendingInsight(
          InsightKind.remaining,
          'You have ${formatMoney(remaining < 0 ? 0 : remaining)} remaining.',
        ),
      );
    }
  } else {
    insights.add(
      const SpendingInsight(
        InsightKind.noBudget,
        'Set a budget to see how much you have left to spend.',
      ),
    );
  }

  if (report.estimatedToBuy > _epsilon) {
    final missing = report.itemsToBuyWithoutPrice;
    final note = missing == 0
        ? ''
        : ' ($missing ${missing == 1 ? 'item has' : 'items have'} no price yet)';
    var text =
        'Your lists still cost about ${formatMoney(report.estimatedToBuy)}'
        '$note.';
    var warning = false;
    if (report.hasBudget) {
      final over = report.projectedSpent - report.budget!.amount;
      if (over > _epsilon) {
        text +=
            ' Buying everything would put you '
            '${formatMoney(over)} over budget.';
        warning = true;
      } else {
        text +=
            ' Buying everything would use '
            '${formatPercent(report.projectedUsage!)} of your budget.';
      }
    }
    insights.add(
      SpendingInsight(InsightKind.projection, text, isWarning: warning),
    );
  }

  // Compare with the previous period only when it has data. Only increases
  // are reported: the current period is not over, so a lower amount today
  // does not mean the user will spend less.
  if (report.previousTotal > _epsilon) {
    CategorySpending? biggestRise;
    var rise = 0.0;
    for (final category in report.byCategory) {
      final before = report.previousByCategory[category.category];
      if (before == null) {
        continue;
      }
      final difference = category.amount - before;
      if (difference > rise + _epsilon) {
        rise = difference;
        biggestRise = category;
      }
    }
    if (biggestRise != null) {
      insights.add(
        SpendingInsight(
          InsightKind.trend,
          'Your spending on ${biggestRise.category} is higher than '
          '${previousPeriodName(report.period)} (+${formatMoney(rise)}).',
          isWarning: true,
        ),
      );
    }
  }

  final lowest = report.lowest;
  if (lowest != null) {
    insights.add(
      SpendingInsight(
        InsightKind.lowestCategory,
        'You spend the least on ${lowest.category}: '
        '${formatMoney(lowest.amount)} '
        '(${formatPercent(lowest.shareOfSpending)} of your spending).',
      ),
    );
  }

  final missing = report.missingPriceCount;
  if (missing > 0) {
    insights.add(
      SpendingInsight(
        InsightKind.missingPrice,
        '$missing ${missing == 1 ? 'purchase has' : 'purchases have'} no '
        'price and ${missing == 1 ? 'is' : 'are'} not counted. Tap '
        '${missing == 1 ? 'it' : 'them'} below to add the price.',
      ),
    );
  }

  return insights;
}
