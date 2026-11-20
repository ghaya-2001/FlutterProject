import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/budget.dart';
import '../../domain/spending_analysis.dart';

/// Colours of the chart, given in order to the categories (highest first).
/// The category colours of the list are too pale for a chart.
const spendingChartColors = <Color>[
  Color(0xFF2E7D32),
  Color(0xFFFFB300),
  Color(0xFFFF7043),
  Color(0xFF42A5F5),
  Color(0xFFAB47BC),
  Color(0xFF26A69A),
  Color(0xFF8D6E63),
  Color(0xFFEC407A),
  Color(0xFF9CCC65),
  Color(0xFF78909C),
];

Color spendingColorAt(int index) =>
    spendingChartColors[index % spendingChartColors.length];

/// Donut chart of the spending per category, with the total in the middle.
class SpendingDonut extends StatelessWidget {
  const SpendingDonut({
    super.key,
    required this.categories,
    required this.total,
    this.size = 170,
  });

  /// Highest first, as in [SpendingReport.byCategory].
  final List<CategorySpending> categories;
  final double total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter([
          for (final category in categories) category.shareOfSpending,
        ]),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Spent',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Text(
                total.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B1B1B),
                ),
              ),
              const Text(
                budgetCurrency,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.shares);

  /// Parts of the circle, between 0 and 1, in drawing order.
  final List<double> shares;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 26.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - stroke / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    if (shares.isEmpty) {
      canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        paint..color = const Color(0xFFE8F5E9),
      );
      return;
    }

    // A small gap between slices when there are several.
    final gap = shares.length > 1 ? 0.03 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < shares.length; i++) {
      final sweep = shares[i] * math.pi * 2;
      if (sweep > gap) {
        canvas.drawArc(
          rect,
          start + gap / 2,
          sweep - gap,
          false,
          paint..color = spendingColorAt(i),
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.shares.length != shares.length ||
      !_sameShares(oldDelegate.shares, shares);

  bool _sameShares(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

/// One line of the legend: colour, icon, name, amount and percentages, with
/// a bar showing the share of the spending.
class SpendingCategoryRow extends StatelessWidget {
  const SpendingCategoryRow({
    super.key,
    required this.spending,
    required this.color,
    required this.icon,
    this.tag,
  });

  final CategorySpending spending;
  final Color color;
  final IconData icon;

  /// "Highest" / "Lowest", shown next to the name.
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final ofBudget = spending.shareOfBudget;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          spending.category,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B1B1B),
                          ),
                        ),
                        if (tag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ofBudget == null
                          ? '${formatPercent(spending.shareOfSpending)} of spending'
                          : '${formatPercent(spending.shareOfSpending)} of spending'
                                ' · ${formatPercent(ofBudget)} of budget',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatMoney(spending.amount),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B1B1B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: spending.shareOfSpending.clamp(0, 1).toDouble(),
              minHeight: 7,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
