/// Currency shown next to every amount.
const budgetCurrency = 'DT';

enum BudgetPeriod { weekly, monthly }

/// The food budget the user sets for a week or a month.
class ShoppingBudget {
  const ShoppingBudget({required this.amount, required this.period});

  final double amount;
  final BudgetPeriod period;

  ShoppingBudget copyWith({double? amount, BudgetPeriod? period}) {
    return ShoppingBudget(
      amount: amount ?? this.amount,
      period: period ?? this.period,
    );
  }
}

/// A time range: [start] included, [end] excluded.
class DateRange {
  const DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);
}

/// The week (Monday to Sunday) or calendar month that contains [now].
DateRange periodRange(BudgetPeriod period, DateTime now) {
  switch (period) {
    case BudgetPeriod.weekly:
      final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      return DateRange(start, DateTime(start.year, start.month, start.day + 7));
    case BudgetPeriod.monthly:
      return DateRange(
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1),
      );
  }
}

/// The week or month just before the one that contains [now].
DateRange previousPeriodRange(BudgetPeriod period, DateTime now) {
  final current = periodRange(period, now);
  return periodRange(period, current.start.subtract(const Duration(days: 1)));
}

/// "this week" / "this month".
String periodName(BudgetPeriod period) =>
    period == BudgetPeriod.weekly ? 'this week' : 'this month';

/// "last week" / "last month".
String previousPeriodName(BudgetPeriod period) =>
    period == BudgetPeriod.weekly ? 'last week' : 'last month';

/// e.g. 12.5 -> "12.50 DT".
String formatMoney(double amount) =>
    '${amount.toStringAsFixed(2)} $budgetCurrency';

/// e.g. 0.4 -> "40%".
String formatPercent(double ratio) => '${(ratio * 100).round()}%';

/// Reads a price typed by the user ("4", "4.5" or "4,5").
///
/// Returns null for an empty field. Throws [FormatException] for text that is
/// not a number, or for a negative number.
double? parsePrice(String text) {
  final trimmed = text.trim().replaceAll(',', '.');
  if (trimmed.isEmpty) {
    return null;
  }
  final value = double.tryParse(trimmed);
  if (value == null || value < 0 || value.isNaN || value.isInfinite) {
    throw const FormatException('Enter a valid amount');
  }
  return value;
}
