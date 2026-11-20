import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../data/budget_repository.dart';
import '../data/shopping_list_repository.dart';
import '../domain/budget.dart';
import '../domain/purchase.dart';
import '../domain/spending_analysis.dart';
import 'widgets/budget_dialogs.dart';
import 'widgets/spending_chart.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "November 2026" or "Week of 16 Nov 2026".
String budgetPeriodLabel(SpendingReport report) {
  final start = report.range.start;
  return report.period == BudgetPeriod.monthly
      ? '${_monthNames[start.month - 1]} ${start.year}'
      : 'Week of ${formatDate(start)}';
}

/// Budget overview, spending per food category, insights and purchases.
class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key, this.budget, this.shopping});

  /// Default to the app-wide instances; injectable for tests.
  final BudgetRepository? budget;
  final ShoppingListRepository? shopping;

  ShoppingListRepository get _shopping =>
      shopping ?? ShoppingListRepository.instance;

  BudgetRepository get _budget =>
      budget ?? _shopping.budget ?? BudgetRepository.instance;

  Future<void> _editBudget(BuildContext context) async {
    final result = await showBudgetDialog(context, current: _budget.budget);
    if (result == null || !context.mounted) {
      return;
    }
    if (result.remove) {
      _budget.removeBudget();
      showAppSnackBar(context, 'Budget removed');
    } else {
      _budget.setBudget(result.amount, result.period);
      showAppSnackBar(context, 'Budget saved: ${formatMoney(result.amount)}');
    }
  }

  Future<void> _editPrice(BuildContext context, Purchase purchase) async {
    final result = await showPriceDialog(
      context,
      itemName: purchase.name,
      current: purchase.amount,
    );
    if (result == null || !context.mounted) {
      return;
    }
    _budget.updatePurchaseAmount(purchase.id, result.amount);
    showAppSnackBar(
      context,
      result.amount == null
          ? 'Price removed for ${purchase.name}'
          : '${purchase.name}: ${formatMoney(result.amount!)}',
    );
  }

  IconData _iconFor(String category) =>
      _shopping.categoryNamed(category)?.icon ?? Icons.shopping_basket_rounded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_budget, _shopping]),
          builder: (context, _) {
            final report = _budget.reportFor(_shopping.allPendingItems);
            final insights = spendingInsights(report);
            final when = periodName(report.period);

            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
              children: [
                ScreenHeader(
                  title: 'Budget & spending',
                  actions: [
                    HeaderIconButton(
                      key: const ValueKey('edit-budget-button'),
                      icon: Icons.edit_rounded,
                      tooltip: report.hasBudget ? 'Edit budget' : 'Set budget',
                      onPressed: () => _editBudget(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _OverviewCard(
                  report: report,
                  onSetBudget: () => _editBudget(context),
                ),
                const SectionTitle('Insights'),
                _InsightsCard(insights: insights),
                SectionTitle('Spending by category $when'),
                if (report.byCategory.isEmpty)
                  EmptyCard(
                    icon: Icons.pie_chart_outline_rounded,
                    message: report.purchases.isEmpty
                        ? 'Tick items on your shopping list as you buy them. '
                              'Your spending per food category will show here.'
                        : 'Add the prices of your purchases below to see your '
                              'spending per category.',
                  )
                else
                  _CategoryBreakdown(report: report, iconFor: _iconFor),
                SectionTitle(
                  'Purchases $when',
                  trailing: Text(
                    '${report.purchases.length}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                ),
                if (report.purchases.isEmpty)
                  const EmptyCard(
                    icon: Icons.receipt_long_outlined,
                    message: 'No purchase yet for this period.',
                  )
                else
                  for (final purchase in report.purchases)
                    _PurchaseTile(
                      purchase: purchase,
                      icon: _iconFor(purchase.categoryName),
                      onTap: () => _editPrice(context, purchase),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Colour of the budget bar: green, then orange from 80%, red when over.
Color budgetUsageColor(double usage) {
  if (usage > 1) return const Color(0xFFC62828);
  if (usage >= 0.8) return const Color(0xFFE65100);
  return const Color(0xFF2E7D32);
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.report, required this.onSetBudget});

  final SpendingReport report;
  final VoidCallback onSetBudget;

  @override
  Widget build(BuildContext context) {
    final remaining = report.remaining;
    final usage = report.usage;

    return Container(
      key: const ValueKey('budget-overview'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB9FBC0), Color(0xFFEAFBE8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  budgetPeriodLabel(report),
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF2E7D32),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (remaining == null) ...[
            const Text(
              'No budget yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1B1B),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Set a weekly or monthly food budget to follow your spending.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              key: const ValueKey('set-budget-button'),
              onPressed: onSetBudget,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Set a budget'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ] else ...[
            Text(
              report.isOverBudget
                  ? '${formatMoney(-remaining)} over budget'
                  : '${formatMoney(remaining)} left',
              key: const ValueKey('budget-remaining'),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: report.isOverBudget
                    ? const Color(0xFFC62828)
                    : const Color(0xFF1B1B1B),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: usage!.clamp(0, 1).toDouble(),
                minHeight: 10,
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation(budgetUsageColor(usage)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${formatPercent(usage)} of your '
              '${report.period == BudgetPeriod.weekly ? 'weekly' : 'monthly'} '
              'budget used',
              key: const ValueKey('budget-usage'),
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (report.hasBudget)
                Expanded(
                  child: _Stat(
                    label: 'Budget',
                    value: formatMoney(report.budget!.amount),
                  ),
                ),
              Expanded(
                child: _Stat(
                  label: 'Spent',
                  value: formatMoney(report.totalSpent),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Still to buy',
                  value: '≈ ${formatMoney(report.estimatedToBuy)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B1B1B),
          ),
        ),
      ],
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});

  final List<SpendingInsight> insights;

  IconData _icon(SpendingInsight insight) {
    switch (insight.kind) {
      case InsightKind.highestCategory:
        return Icons.trending_up_rounded;
      case InsightKind.lowestCategory:
        return Icons.trending_down_rounded;
      case InsightKind.budgetUsage:
        return Icons.donut_large_rounded;
      case InsightKind.remaining:
        return Icons.savings_outlined;
      case InsightKind.overBudget:
        return Icons.warning_amber_rounded;
      case InsightKind.projection:
        return Icons.shopping_cart_outlined;
      case InsightKind.trend:
        return Icons.compare_arrows_rounded;
      case InsightKind.missingPrice:
        return Icons.edit_note_rounded;
      case InsightKind.noData:
      case InsightKind.noBudget:
        return Icons.lightbulb_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('budget-insights'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          for (final insight in insights)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _icon(insight),
                    size: 22,
                    color: insight.isWarning
                        ? const Color(0xFFE65100)
                        : const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      insight.text,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.report, required this.iconFor});

  final SpendingReport report;
  final IconData Function(String category) iconFor;

  @override
  Widget build(BuildContext context) {
    final categories = report.byCategory;
    return Container(
      key: const ValueKey('spending-breakdown'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          SpendingDonut(categories: categories, total: report.totalSpent),
          const SizedBox(height: 12),
          for (var i = 0; i < categories.length; i++)
            SpendingCategoryRow(
              spending: categories[i],
              color: spendingColorAt(i),
              icon: iconFor(categories[i].category),
              tag: categories.length < 2
                  ? null
                  : i == 0
                  ? 'Highest'
                  : i == categories.length - 1
                  ? 'Lowest'
                  : null,
            ),
        ],
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({
    required this.purchase,
    required this.icon,
    required this.onTap,
  });

  final Purchase purchase;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount = purchase.amount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('purchase-${purchase.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        purchase.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1B1B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${purchase.quantity} ${purchase.unit} · '
                        '${purchase.categoryName} · ${formatDate(purchase.date)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                amount == null
                    ? const Text(
                        'Add price',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE65100),
                        ),
                      )
                    : Text(
                        formatMoney(amount),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1B1B),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
