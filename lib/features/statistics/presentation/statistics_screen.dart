import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../donations/data/donation_repository.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../recipes/data/saved_recipes_repository.dart';
import '../domain/activity.dart';
import '../domain/impact.dart';
import 'activity_history_screen.dart';
import 'widgets/activity_tile.dart';

const _green = Color(0xFF2E7D32);
const _red = Color(0xFFC62828);
const _dark = Color(0xFF1B1B1B);
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Statistics" screen (Membre 5): meals saved, environmental impact,
/// anti-waste score and recent actions.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    super.key,
    this.fridge,
    this.donations,
    this.savedRecipes,
  });

  /// Default to the app-wide instances; injectable for tests.
  final FridgeRepository? fridge;
  final DonationRepository? donations;
  final SavedRecipesRepository? savedRecipes;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  StatsPeriod _period = StatsPeriod.week;

  FridgeRepository get _fridge => widget.fridge ?? FridgeRepository.instance;
  DonationRepository get _donations =>
      widget.donations ?? DonationRepository.instance;
  SavedRecipesRepository get _saved =>
      widget.savedRecipes ?? SavedRecipesRepository.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_fridge, _donations, _saved]),
          builder: (context, _) {
            final stats = ImpactStats.from(
              history: _fridge.history,
              donations: _donations.donations,
              now: _fridge.now,
              period: _period,
            );
            final activity = buildActivity(
              history: _fridge.history,
              donations: _donations.donations,
              savedRecipes: _saved.saved,
            );
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              children: [
                const ScreenHeader(title: 'Statistics'),
                const SizedBox(height: 16),
                SegmentedButton<StatsPeriod>(
                  key: const ValueKey('stats-period'),
                  segments: [
                    for (final period in StatsPeriod.values)
                      ButtonSegment(value: period, label: Text(period.label)),
                  ],
                  selected: {_period},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      setState(() => _period = selection.first),
                ),
                const SizedBox(height: 18),
                _HeroCard(stats: stats),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        key: const ValueKey('stats-food-saved'),
                        icon: Icons.scale_rounded,
                        color: const Color(0xFFB2DFDB),
                        value: '${formatAmount(stats.savedKg)} kg',
                        label: 'Food saved',
                        detail: '${stats.savedCount} foods',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _StatTile(
                        key: const ValueKey('stats-co2'),
                        icon: Icons.cloud_outlined,
                        color: const Color(0xFFBBDEFB),
                        value: '${formatAmount(stats.co2AvoidedKg)} kg',
                        label: 'CO₂ avoided',
                        detail: '≈ ${formatAmount(stats.carKm)} km by car',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        key: const ValueKey('stats-score'),
                        icon: Icons.emoji_events_outlined,
                        color: const Color(0xFFFFE082),
                        value: stats.score == null ? '—' : '${stats.score}%',
                        label: 'Anti-waste score',
                        detail: 'Saved vs thrown away',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _StatTile(
                        key: const ValueKey('stats-wasted'),
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFFFCDD2),
                        value: '${stats.wastedCount}',
                        label: 'Foods wasted',
                        detail: '${formatAmount(stats.co2LostKg)} kg CO₂ lost',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _WeekChart(days: stats.lastDays()),
                const SectionTitle('Where your savings come from'),
                _Breakdown(stats: stats),
                SectionTitle(
                  'Recent activity',
                  trailing: TextButton(
                    key: const ValueKey('stats-see-all'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => ActivityHistoryScreen(
                          fridge: _fridge,
                          donations: _donations,
                          savedRecipes: _saved,
                        ),
                      ),
                    ),
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (activity.isEmpty)
                  const EmptyCard(
                    icon: Icons.history_rounded,
                    message:
                        'No activity yet. Eat, cook or donate your food to '
                        'see it here.',
                  )
                else
                  _Card(
                    child: Column(
                      children: [
                        for (final entry in activity.take(5))
                          ActivityTile(entry: entry, now: _fridge.now),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                const _HowItWorks(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});

  final ImpactStats stats;

  @override
  Widget build(BuildContext context) {
    final meals = stats.mealsSaved;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.period.label,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '$meals ${meals == 1 ? 'meal' : 'meals'} saved',
                  key: const ValueKey('stats-meals'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  meals == 0
                      ? 'Eat, cook or donate the food that expires soon to '
                            'start saving meals.'
                      : 'That is ${formatAmount(stats.savedKg)} kg of food '
                            'kept out of the bin.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _dark, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _dark,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _dark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days});

  final List<DayImpact> days;

  static const _maxBarHeight = 110.0;

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
              _Legend(color: _green, label: 'Saved'),
              SizedBox(width: 14),
              _Legend(color: _red, label: 'Wasted'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            // Bars (with their gaps) + count label above + weekday below.
            height: _maxBarHeight + 64,
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
                        if (day.wasted > 0)
                          _Bar(
                            height: _maxBarHeight * day.wasted / highest,
                            color: _red,
                          ),
                        if (day.saved > 0)
                          _Bar(
                            height: _maxBarHeight * day.saved / highest,
                            color: _green,
                          ),
                        if (day.total == 0)
                          Container(
                            width: 20,
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
  const _Bar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: height,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
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

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.stats});

  final ImpactStats stats;

  static const _icons = {
    ImpactSource.eaten: Icons.lunch_dining_rounded,
    ImpactSource.cooked: Icons.restaurant_menu_rounded,
    ImpactSource.donated: Icons.volunteer_activism_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final total = stats.savedCount;
    return _Card(
      child: Column(
        children: [
          for (final source in _icons.keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(_icons[source], color: _green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                source.label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _dark,
                                ),
                              ),
                            ),
                            Text(
                              '${stats.countFor(source)}',
                              key: ValueKey('stats-breakdown-${source.name}'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _dark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: total == 0
                                ? 0
                                : stats.countFor(source) / total,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE8F5E9),
                            color: _green,
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

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: const ExpansionTile(
          key: ValueKey('stats-how'),
          leading: Icon(Icons.info_outline_rounded, color: _green),
          title: Text(
            'How is this calculated?',
            style: TextStyle(fontWeight: FontWeight.w600, color: _dark),
          ),
          childrenPadding: EdgeInsets.fromLTRB(18, 0, 18, 18),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• A food is saved when you eat it, cook it in a recipe or '
              'donate it and it is collected. It is wasted when you throw '
              'it away.\n'
              '• Weight: kg and L as they are, g and ml / 1000, pieces and '
              'packs use an average weight per category.\n'
              '• 1 meal ≈ 400 g of food.\n'
              '• CO₂: weight × an average emission factor per category '
              '(e.g. 0.8 kg CO₂/kg for vegetables, 15 for meat & fish), '
              'simplified from Poore & Nemecek (2018).\n'
              '• Car: about 120 g of CO₂ per km.\n'
              '• Score: saved foods / (saved + wasted).',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
