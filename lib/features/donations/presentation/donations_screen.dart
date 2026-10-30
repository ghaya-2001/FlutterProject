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

enum _DonationTab { mine, available }

/// Main donations screen.
///
/// "My donations": foods worth donating and the user's active donations.
/// "Available": what partner restaurants and charities see and can request.
class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key, this.repository});

  /// Defaults to [DonationRepository.instance]; injectable for tests.
  final DonationRepository? repository;

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  _DonationTab _tab = _DonationTab.mine;

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

  Future<void> _request(Donation donation) async {
    final name = await showRequestDonationSheet(
      context,
      repository: _repository,
      donation: donation,
    );
    if (name != null && mounted) {
      showAppSnackBar(context, 'Request sent by $name');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _tab == _DonationTab.mine
          ? FloatingActionButton.extended(
              key: const ValueKey('new-donation-button'),
              onPressed: _create,
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New donation'),
            )
          : null,
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
                SegmentedButton<_DonationTab>(
                  segments: const [
                    ButtonSegment(
                      value: _DonationTab.mine,
                      label: Text('My donations'),
                      icon: Icon(Icons.volunteer_activism_rounded),
                    ),
                    ButtonSegment(
                      value: _DonationTab.available,
                      label: Text('Available'),
                      icon: Icon(Icons.storefront_rounded),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (selection) =>
                      setState(() => _tab = selection.first),
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Colors.white,
                    selectedBackgroundColor: const Color(0xFFC8E6C9),
                    selectedForegroundColor: const Color(0xFF1B5E20),
                  ),
                ),
                if (_tab == _DonationTab.mine)
                  ..._buildMine()
                else
                  ..._buildAvailable(),
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

  List<Widget> _buildAvailable() {
    final available = _repository.availableDonations;
    return [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF1565C0)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This is what partner restaurants and charities see. '
                'Tap "Request" to simulate a request from one of them.',
                style: TextStyle(fontSize: 13, color: Color(0xFF1B1B1B)),
              ),
            ),
          ],
        ),
      ),
      const SectionTitle('Available donations'),
      if (available.isEmpty)
        const EmptyCard(
          icon: Icons.inventory_2_outlined,
          message: 'No donation is available right now.',
        )
      else
        for (final donation in available)
          DonationCard(
            donation: donation,
            onTap: () => _openDetails(donation),
            trailing: TextButton(
              onPressed: () => _request(donation),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF2E7D32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Request'),
            ),
          ),
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
                  '${repository.collectedCount} donations collected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  requests == 0
                      ? 'No request waiting for your answer.'
                      : '$requests ${requests == 1 ? 'request' : 'requests'} '
                            'waiting for your answer.',
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
