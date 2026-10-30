import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../data/donation_repository.dart';
import '../domain/donation.dart';
import 'donation_details_screen.dart';
import 'widgets/donation_widgets.dart';

/// Every donation the user published, newest first, filterable by status.
class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key, this.repository});

  /// Defaults to [DonationRepository.instance]; injectable for tests.
  final DonationRepository? repository;

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  /// null = all statuses.
  DonationStatus? _filter;

  DonationRepository get _repository =>
      widget.repository ?? DonationRepository.instance;

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
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _repository,
          builder: (context, _) {
            final all = _repository.donations;
            final shown = _filter == null
                ? all
                : all.where((d) => d.status == _filter).toList();

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              children: [
                const ScreenHeader(title: 'Donation history'),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _CountCard(
                        value: '${all.length}',
                        label: 'Published',
                        color: const Color(0xFFB2DFDB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CountCard(
                        value: '${_repository.collectedCount}',
                        label: 'Collected',
                        color: const Color(0xFFBBDEFB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filter == null,
                      onSelected: () => setState(() => _filter = null),
                    ),
                    for (final status in DonationStatus.values)
                      _FilterChip(
                        label: donationStatusLabel(status),
                        selected: _filter == status,
                        onSelected: () => setState(() => _filter = status),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                if (shown.isEmpty)
                  const EmptyCard(
                    icon: Icons.history_rounded,
                    message: 'No donation here yet.',
                  )
                else
                  for (final donation in shown)
                    DonationCard(
                      donation: donation,
                      onTap: () => _openDetails(donation),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFC8E6C9),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.volunteer_activism_rounded,
              color: Color(0xFF1B1B1B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B1B1B),
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
