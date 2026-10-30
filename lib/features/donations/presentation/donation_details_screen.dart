import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../data/donation_repository.dart';
import '../domain/beneficiary.dart';
import '../domain/donation.dart';
import 'widgets/donation_widgets.dart';

/// Details of one donation: status, requests and the donor's actions.
///
/// Pops with a message when the donation is cancelled.
class DonationDetailsScreen extends StatelessWidget {
  const DonationDetailsScreen({
    super.key,
    required this.repository,
    required this.donationId,
  });

  final DonationRepository repository;
  final String donationId;

  Future<void> _simulateRequest(BuildContext context, Donation donation) async {
    final name = await showRequestDonationSheet(
      context,
      repository: repository,
      donation: donation,
    );
    if (name != null && context.mounted) {
      showAppSnackBar(context, 'Request sent by $name');
    }
  }

  void _accept(BuildContext context, Donation donation, DonationRequest r) {
    repository.acceptRequest(donation.id, r.id);
    showAppSnackBar(
      context,
      '${donation.foodName} reserved for ${r.beneficiary.name}',
    );
  }

  void _refuse(BuildContext context, Donation donation, DonationRequest r) {
    repository.refuseRequest(donation.id, r.id);
    showAppSnackBar(context, 'Request from ${r.beneficiary.name} refused');
  }

  void _collected(BuildContext context, Donation donation) {
    repository.markCollected(donation.id);
    showAppSnackBar(context, 'Thank you! ${donation.foodName} was collected');
  }

  Future<void> _cancel(BuildContext context, Donation donation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Cancel donation?'),
        content: Text(
          '${donationQuantityLabel(donation)} of ${donation.foodName} will go '
          'back to your fridge.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Keep it',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Yes, cancel',
              style: TextStyle(color: Color(0xFFC62828)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    repository.cancelDonation(donation.id);
    Navigator.of(context).pop('Donation cancelled, food back in your fridge');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: repository,
          builder: (context, _) {
            final donation = repository.donationById(donationId);
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              children: [
                const ScreenHeader(title: 'Donation'),
                const SizedBox(height: 18),
                if (donation == null)
                  const EmptyCard(
                    icon: Icons.search_off_rounded,
                    message: 'This donation no longer exists.',
                  )
                else
                  ..._buildDetails(context, donation),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildDetails(BuildContext context, Donation donation) {
    final accepted = donation.acceptedRequest;
    final isAvailable = donation.status == DonationStatus.available;
    // Only the donor can answer requests, collect or cancel.
    final isMine = repository.isMine(donation);

    return [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [donation.category.color, const Color(0xFFE8F5E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                donation.category.icon,
                size: 34,
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    donation.foodName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${donationQuantityLabel(donation)} · '
                    '${donation.category.name}',
                    style: const TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  DonationStatusChip(status: donation.status),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _StatusSteps(status: donation.status),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.event_rounded,
              label: 'Consume before',
              value: formatDate(donation.expiryDate),
            ),
            _InfoRow(
              icon: Icons.schedule_rounded,
              label: 'Published on',
              value: formatDate(donation.createdAt),
            ),
            if (donation.collectedAt != null)
              _InfoRow(
                icon: Icons.task_alt_rounded,
                label: 'Collected on',
                value: formatDate(donation.collectedAt!),
              ),
            if (donation.description.isNotEmpty)
              _InfoRow(
                icon: Icons.notes_rounded,
                label: 'Description',
                value: donation.description,
              ),
          ],
        ),
      ),
      if (accepted != null) ...[
        const SectionTitle('Beneficiary'),
        _RequestCard(request: accepted),
      ],
      if (isMine && donation.status == DonationStatus.reserved) ...[
        const SizedBox(height: 8),
        _PrimaryButton(
          key: const ValueKey('mark-collected-button'),
          icon: Icons.task_alt_rounded,
          label: 'Mark as collected',
          onPressed: () => _collected(context, donation),
        ),
      ],
      if (isAvailable) ...[
        SectionTitle(
          'Requests',
          trailing: TextButton.icon(
            key: const ValueKey('simulate-request-button'),
            onPressed: () => _simulateRequest(context, donation),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Simulate'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2E7D32),
            ),
          ),
        ),
        if (donation.pendingRequests.isEmpty)
          const EmptyCard(
            icon: Icons.hourglass_empty_rounded,
            message:
                'No request yet. Restaurants and charities can see your '
                'donation in "Available".',
          )
        else
          for (final request in donation.pendingRequests)
            _RequestCard(
              request: request,
              onAccept: isMine
                  ? () => _accept(context, donation, request)
                  : null,
              onRefuse: isMine
                  ? () => _refuse(context, donation, request)
                  : null,
            ),
        if (isMine) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              key: const ValueKey('cancel-donation-button'),
              onPressed: () => _cancel(context, donation),
              icon: const Icon(Icons.undo_rounded),
              label: const Text(
                'Cancel donation',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFC62828)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ],
    ];
  }
}

/// Available → Reserved → Collected.
class _StatusSteps extends StatelessWidget {
  const _StatusSteps({required this.status});

  final DonationStatus status;

  @override
  Widget build(BuildContext context) {
    final current = DonationStatus.values.indexOf(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          for (final step in DonationStatus.values) ...[
            Expanded(
              child: Column(
                children: [
                  Icon(
                    DonationStatus.values.indexOf(step) <= current
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: DonationStatus.values.indexOf(step) <= current
                        ? donationStatusColor(step)
                        : Colors.black26,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    donationStatusLabel(step),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: step == status
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: const Color(0xFF1B1B1B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, this.onAccept, this.onRefuse});

  final DonationRequest request;
  final VoidCallback? onAccept;
  final VoidCallback? onRefuse;

  @override
  Widget build(BuildContext context) {
    final beneficiary = request.beneficiary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  beneficiaryTypeIcon(beneficiary.type),
                  color: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      beneficiary.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                    Text(
                      '${beneficiaryTypeLabel(beneficiary.type)} · '
                      '${beneficiary.area}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (onAccept == null)
                Text(
                  requestStatusLabel(request.status),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
            ],
          ),
          if (request.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '“${request.message}”',
              style: const TextStyle(fontSize: 14, color: Color(0xFF1B1B1B)),
            ),
          ],
          if (onAccept != null && onRefuse != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
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
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B1B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
