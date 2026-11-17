import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../donations/data/donation_repository.dart';
import '../../donations/domain/donation.dart';
import '../../donations/presentation/widgets/donation_widgets.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../../profile/data/user_profile_repository.dart';

/// History tab of restaurants and admins: one line per donation request,
/// newest first, filterable by answer.
///
/// A restaurant sees the requests it sent (including the pending ones); the
/// admin sees every request that was answered, with who asked.
class RequestHistoryTab extends StatefulWidget {
  const RequestHistoryTab({
    super.key,
    required this.title,
    required this.emptyMessage,
    required this.forRestaurant,
    this.donations,
    this.profiles,
  });

  final String title;
  final String emptyMessage;

  /// True: only the requests of the signed-in restaurant, pending included.
  /// False (admin): every answered request, with the requester's name.
  final bool forRestaurant;

  /// Default to the app-wide instances; injectable for tests.
  final DonationRepository? donations;
  final UserProfileRepository? profiles;

  @override
  State<RequestHistoryTab> createState() => _RequestHistoryTabState();
}

class _RequestHistoryTabState extends State<RequestHistoryTab> {
  /// null = every answer.
  RequestStatus? _filter;

  DonationRepository get _donations =>
      widget.donations ?? DonationRepository.instance;
  UserProfileRepository get _profiles =>
      widget.profiles ?? UserProfileRepository.instance;

  @override
  void initState() {
    super.initState();
    _donations.refresh();
  }

  List<RequestStatus> get _filters => [
    if (widget.forRestaurant) RequestStatus.pending,
    RequestStatus.accepted,
    RequestStatus.refused,
  ];

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _donations.refresh,
      child: ListenableBuilder(
        listenable: Listenable.merge([_donations, _profiles]),
        builder: (context, _) {
          final all = _donations.requestRecords(
            beneficiaryId: widget.forRestaurant
                ? (_profiles.profile?.uid ?? '')
                : null,
            includePending: widget.forRestaurant,
          );
          final shown = _filter == null
              ? all
              : all.where((record) => record.request.status == _filter);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                  ),
                  HeaderIconButton(
                    key: const ValueKey('history-refresh-button'),
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh',
                    onPressed: _donations.refresh,
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
                  for (final status in _filters)
                    _FilterChip(
                      key: ValueKey('history-filter-${status.name}'),
                      label: requestHistoryLabel(status),
                      selected: _filter == status,
                      onSelected: () => setState(() => _filter = status),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (shown.isEmpty)
                EmptyCard(
                  icon: Icons.history_rounded,
                  message: all.isEmpty
                      ? widget.emptyMessage
                      : 'No request with this answer.',
                )
              else
                for (final record in shown)
                  _RecordTile(
                    key: ValueKey('history-${record.request.id}'),
                    record: record,
                    showRequester: !widget.forRestaurant,
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
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

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    super.key,
    required this.record,
    required this.showRequester,
  });

  final RequestRecord record;
  final bool showRequester;

  @override
  Widget build(BuildContext context) {
    final donation = record.donation;
    final request = record.request;
    final details = [
      if (showRequester) 'Requested by ${request.beneficiary.name}',
      'Sent ${formatDate(request.createdAt)}',
      'Donation ${donationStatusLabel(donation.status).toLowerCase()}',
    ].join(' · ');
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: donation.category.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(donation.category.icon, color: const Color(0xFF1B1B1B)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${donation.foodName} · ${donationQuantityLabel(donation)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                if (request.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '“${request.message}”',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: requestStatusBackground(request.status),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              requestHistoryLabel(request.status),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: requestStatusColor(request.status),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
