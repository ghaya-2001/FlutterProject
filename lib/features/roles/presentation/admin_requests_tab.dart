import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../donations/data/donation_repository.dart';
import '../../donations/domain/donation.dart';
import '../../donations/presentation/widgets/donation_widgets.dart';

/// Requests tab of the admin: every donation with a pending request from a
/// restaurant, with buttons to accept or refuse each request.
class AdminRequestsTab extends StatefulWidget {
  const AdminRequestsTab({
    super.key,
    required this.title,
    required this.emptyMessage,
    this.donations,
  });

  final String title;
  final String emptyMessage;

  /// Defaults to [DonationRepository.instance]; injectable for tests.
  final DonationRepository? donations;

  @override
  State<AdminRequestsTab> createState() => _AdminRequestsTabState();
}

class _AdminRequestsTabState extends State<AdminRequestsTab> {
  DonationRepository get _donations =>
      widget.donations ?? DonationRepository.instance;

  @override
  void initState() {
    super.initState();
    // Requests sent after sign-in are only visible after a reload.
    _donations.refresh();
  }

  void _answer(Donation donation, DonationRequest request, bool accept) {
    try {
      if (accept) {
        _donations.acceptRequest(donation.id, request.id);
      } else {
        _donations.refuseRequest(donation.id, request.id);
      }
      showAppSnackBar(
        context,
        accept
            ? 'Request from ${request.beneficiary.name} accepted'
            : 'Request from ${request.beneficiary.name} refused',
      );
    } on StateError catch (error) {
      showAppSnackBar(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _donations.refresh,
      child: ListenableBuilder(
        listenable: _donations,
        builder: (context, _) {
          final waiting = _donations.donationsAwaitingAnswer;
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
                    key: const ValueKey('admin-refresh-button'),
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh',
                    onPressed: _donations.refresh,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (waiting.isEmpty)
                EmptyCard(
                  icon: Icons.fact_check_outlined,
                  message: widget.emptyMessage,
                )
              else
                for (final donation in waiting) ...[
                  DonationCard(
                    key: ValueKey('admin-donation-${donation.id}'),
                    donation: donation,
                    onTap: () {},
                  ),
                  for (final request in donation.pendingRequests)
                    _RequestTile(
                      key: ValueKey('admin-request-${request.id}'),
                      request: request,
                      onAccept: () => _answer(donation, request, true),
                      onRefuse: () => _answer(donation, request, false),
                    ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onRefuse,
  });

  final DonationRequest request;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.beneficiary.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B1B1B),
            ),
          ),
          if (request.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '“${request.message}”',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: ValueKey('refuse-${request.id}'),
                  onPressed: onRefuse,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                    side: const BorderSide(color: Color(0xFFC62828)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Refuse'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  key: ValueKey('accept-${request.id}'),
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
