import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../fridge/domain/food_item.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../data/donation_repository.dart';
import '../domain/donation.dart';
import 'create_donation_screen.dart';
import 'donation_details_screen.dart';
import 'donation_history_screen.dart';
import 'widgets/donation_widgets.dart';

/// Main donations screen.
///
/// Foods worth donating and the user's active donations. Users only offer
/// food: restaurants are the ones who request it (see `RoleHome`).
class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key, this.repository});

  /// Defaults to [DonationRepository.instance]; injectable for tests.
  final DonationRepository? repository;

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  DonationRepository get _repository =>
      widget.repository ?? DonationRepository.instance;

  Future<void> _create({String? foodId}) async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => CreateDonationScreen(
          repository: _repository,
          initialFoodId: foodId,
        ),
      ),
    );
    if (name != null && mounted) {
      showAppSnackBar(context, '$name offered for donation');
    }
  }

  Future<void> _openDetails(Donation donation) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => DonationDetailsScreen(
          repository: _repository,
          donationId: donation.id,
        ),
      ),
    );
    if (message != null && mounted) {
      showAppSnackBar(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-donation-button'),
        onPressed: _create,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New donation'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_repository, _repository.fridge]),
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 96),
              children: [
                ScreenHeader(
                  title: 'Donations',
                  actions: [
                    HeaderIconButton(
                      icon: Icons.history_rounded,
                      tooltip: 'Donation history',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              DonationHistoryScreen(repository: _repository),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SummaryCard(repository: _repository),
                const SizedBox(height: 18),
                ..._buildMine(),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildMine() {
    final suggested = _repository.suggestedFoods;
    final active = _repository.activeDonations;
    return [
      const SectionTitle('Could be donated'),
      if (suggested.isEmpty)
        const EmptyCard(
          icon: Icons.eco_outlined,
          message: 'No food expires in the next 7 days.',
        )
      else
        for (final food in suggested)
          _SuggestedFoodTile(
            food: food,
            now: _repository.now,
            onDonate: () => _create(foodId: food.id),
          ),
      const SectionTitle('My active donations'),
      if (active.isEmpty)
        const EmptyCard(
          icon: Icons.volunteer_activism_outlined,
          message: 'You have no active donation.',
        )
      else
        for (final donation in active)
          DonationCard(donation: donation, onTap: () => _openDetails(donation)),
    ];
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.repository});

  final DonationRepository repository;

  @override
  Widget build(BuildContext context) {
    final requests = repository.pendingRequestCount;
    return Container(
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
                  '${repository.acceptedCount} '
                  '${repository.acceptedCount == 1 ? 'donation' : 'donations'} accepted',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  requests > 0
                      ? '$requests ${requests == 1 ? 'request' : 'requests'} '
                            'from restaurants waiting for the admin.'
                      : repository.reservedCount > 0
                      ? '${repository.reservedCount} reserved, waiting to be '
                            'collected.'
                      : 'No request from restaurants yet.',
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
              Icons.volunteer_activism_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedFoodTile extends StatelessWidget {
  const _SuggestedFoodTile({
    required this.food,
    required this.now,
    required this.onDonate,
  });

  final FoodItem food;
  final DateTime now;
  final VoidCallback onDonate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: food.category.color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(food.category.icon, color: const Color(0xFF1B1B1B)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${quantityLabel(food)} · ${daysLeftLabel(food, now)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: statusColor(food.status(now)),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            key: ValueKey('donate-${food.id}'),
            onPressed: onDonate,
            icon: const Icon(Icons.volunteer_activism_rounded, size: 18),
            label: const Text('Donate'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }
}
