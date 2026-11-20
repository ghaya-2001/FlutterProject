import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../data/donation_repository.dart';
import '../domain/donation_leaderboard.dart';

/// Ranked list of the most donated foods, from the completed donations of
/// every user.
class DonationLeaderboardScreen extends StatefulWidget {
  const DonationLeaderboardScreen({super.key, this.repository});

  /// Defaults to [DonationRepository.instance]; injectable for tests.
  final DonationRepository? repository;

  @override
  State<DonationLeaderboardScreen> createState() =>
      _DonationLeaderboardScreenState();
}

class _DonationLeaderboardScreenState extends State<DonationLeaderboardScreen> {
  DonationRepository get _repository =>
      widget.repository ?? DonationRepository.instance;

  @override
  void initState() {
    super.initState();
    // Picks up donations completed by other users since sign-in.
    _repository.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _repository,
          builder: (context, _) {
            final entries = _repository.leaderboard;
            return RefreshIndicator(
              color: const Color(0xFF2E7D32),
              onRefresh: _repository.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
                children: [
                  const ScreenHeader(title: 'Top donated foods'),
                  const SizedBox(height: 18),
                  _SummaryCard(
                    completed: _repository.completedDonationCount,
                    foods: entries.length,
                  ),
                  const SectionTitle('Leaderboard'),
                  if (entries.isEmpty)
                    const EmptyCard(
                      icon: Icons.emoji_events_outlined,
                      message:
                          'No completed donation yet. Foods appear here once '
                          'a donation has been collected.',
                    )
                  else
                    for (var i = 0; i < entries.length; i++)
                      _LeaderboardRow(rank: i + 1, entry: entries[i]),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.completed, required this.foods});

  final int completed;
  final int foods;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
                  completed == 1
                      ? '1 completed donation'
                      : '$completed completed donations',
                  key: const ValueKey('leaderboard-summary'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  foods == 1
                      ? '1 food shared with the community'
                      : '$foods different foods shared with the community',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.entry});

  final int rank;
  final LeaderboardEntry entry;

  /// Gold, silver and bronze for the podium, green for the others.
  Color get _rankColor {
    switch (rank) {
      case 1:
        return const Color(0xFFFFB300);
      case 2:
        return const Color(0xFF90A4AE);
      case 3:
        return const Color(0xFFBF8040);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    final times = entry.timesDonated;
    return Container(
      key: ValueKey('leaderboard-row-$rank'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _rankColor.withValues(alpha: rank <= 3 ? 1 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rank <= 3 ? Colors.white : _rankColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: entry.category.color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(entry.category.icon, color: const Color(0xFF1B1B1B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.foodName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  times == 1 ? 'Donated 1 time' : 'Donated $times times',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${formatQuantity(entry.totalQuantity)} ${entry.unit}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B1B1B),
                ),
              ),
              const Text(
                'in total',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
