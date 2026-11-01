import 'package:flutter/material.dart';

import '../data/fridge_repository.dart';
import '../domain/food_category.dart';
import '../domain/fridge_event.dart';
import '../domain/fridge_formatters.dart';
import '../domain/fridge_stats.dart';

const _green = Color(0xFF2E7D32);
const _red = Color(0xFFC62828);
const _dark = Color(0xFF1B1B1B);

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Anti-waste statistics: how many foods were eaten instead of thrown away.
class FridgeStatsScreen extends StatelessWidget {
  const FridgeStatsScreen({super.key, required this.repository});

  final FridgeRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: repository,
          builder: (context, _) {
            final stats = repository.stats;
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: _dark,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Anti-waste stats',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _dark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (stats.isEmpty)
                  const _NoHistory()
                else ...[
                  _ScoreCard(stats: stats),
                  const SizedBox(height: 16),
                  _WeekChart(days: stats.lastDays),
                  if (stats.wastedByCategory.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _WastedCategories(entries: stats.wastedByCategory),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'Recent activity',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final event in repository.history.take(10)) ...[
                    _EventTile(event: event),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.gradient});

  final Widget child;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: gradient == null ? Colors.white : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(26),
      ),
      child: child,
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.stats});

  final FridgeStats stats;

  @override
  Widget build(BuildContext context) {
    final score = stats.score ?? 0;
    final color = score >= 80
        ? _green
        : score >= 50
        ? const Color(0xFFF9A825)
        : _red;
    final streak = stats.daysWithoutWaste ?? 0;

    return _Card(
      gradient: const LinearGradient(
        colors: [Color(0xFFE0F7FA), Color(0xFFE8F5E9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score / 100),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 11,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white,
                    color: color,
                  ),
                  Center(
                    child: Text(
                      '${(value * 100).round()}%',
                      key: const ValueKey('anti-waste-score'),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Anti-waste score',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Foods eaten instead of thrown away',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      icon: Icons.restaurant_rounded,
                      label: '${stats.consumedCount} eaten',
                      color: _green,
                    ),
                    _Pill(
                      icon: Icons.delete_outline_rounded,
                      label: '${stats.wastedCount} wasted',
                      color: _red,
                    ),
                    _Pill(
                      icon: Icons.local_fire_department_rounded,
                      label:
                          '$streak ${streak == 1 ? 'day' : 'days'} '
                          'without waste',
                      color: const Color(0xFFE65100),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stacked bars: eaten (green) and wasted (red) foods of the last days.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days});

  final List<DayStats> days;

  static const _maxBarHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final highest = days.fold<int>(
      1,
      (max, d) => d.total > max ? d.total : max,
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last 7 days',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              _Legend(color: _green, label: 'Eaten'),
              SizedBox(width: 14),
              _Legend(color: _red, label: 'Wasted'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            // Bar + count label above + weekday label below.
            height: _maxBarHeight + 52,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in days)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (day.total > 0)
                          Text(
                            '${day.total}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                        const SizedBox(height: 4),
                        _Bar(
                          height: _maxBarHeight * day.wasted / highest,
                          color: _red,
                          top: true,
                          bottom: day.consumed == 0,
                        ),
                        _Bar(
                          height: _maxBarHeight * day.consumed / highest,
                          color: _green,
                          top: day.wasted == 0,
                          bottom: true,
                        ),
                        if (day.total == 0)
                          Container(
                            width: 22,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          _weekdays[day.date.weekday - 1],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
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

class _Bar extends StatelessWidget {
  const _Bar({
    required this.height,
    required this.color,
    required this.top,
    required this.bottom,
  });

  final double height;
  final Color color;
  final bool top;
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: height),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Container(
        width: 22,
        height: value,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.vertical(
            top: top ? radius : Radius.zero,
            bottom: bottom ? radius : Radius.zero,
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class _WastedCategories extends StatelessWidget {
  const _WastedCategories({required this.entries});

  final List<MapEntry<FoodCategory, int>> entries;

  @override
  Widget build(BuildContext context) {
    final highest = entries.first.value;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Most wasted categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Buy smaller quantities of these',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 14),
          for (final entry in entries.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: entry.key.color,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(entry.key.icon, size: 18, color: _dark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: entry.value / highest,
                            minHeight: 7,
                            backgroundColor: const Color(0xFFFFEBEE),
                            color: _red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _red,
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

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final FridgeEvent event;

  @override
  Widget build(BuildContext context) {
    final color = event.isWaste ? _red : _green;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              event.isWaste
                  ? Icons.delete_outline_rounded
                  : Icons.restaurant_rounded,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.foodName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                Text(
                  '${event.isWaste ? 'Thrown away' : 'Eaten'} · '
                  '${formatQuantity(event.quantity)} ${event.unit}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          Text(
            formatDate(event.at),
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

class _NoHistory extends StatelessWidget {
  const _NoHistory();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.insights_rounded, size: 36, color: _green),
          ),
          const SizedBox(height: 16),
          const Text(
            'No statistics yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Consume foods from your fridge, or throw away the expired ones, '
            'to see your anti-waste score.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
