import 'package:flutter/material.dart';

import '../../../fridge/domain/fridge_formatters.dart';
import '../../data/donation_repository.dart';
import '../../domain/beneficiary.dart';
import '../../domain/donation.dart';

String donationQuantityLabel(Donation donation) =>
    '${formatQuantity(donation.quantity)} ${donation.unit}';

/// Small coloured label: "Available", "Reserved" or "Collected".
class DonationStatusChip extends StatelessWidget {
  const DonationStatusChip({super.key, required this.status});

  final DonationStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: donationStatusBackground(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        donationStatusLabel(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: donationStatusColor(status),
        ),
      ),
    );
  }
}

/// One donation in a list.
class DonationCard extends StatelessWidget {
  const DonationCard({
    super.key,
    required this.donation,
    required this.onTap,
    this.trailing,
  });

  final Donation donation;
  final VoidCallback onTap;

  /// Replaces the status chip (used for the "Request" button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pending = donation.pendingRequests.length;
    final accepted = donation.acceptedRequest;
    final String subtitle;
    if (donation.status == DonationStatus.available) {
      subtitle = pending == 0
          ? 'Use by ${formatDate(donation.expiryDate)}'
          : '$pending ${pending == 1 ? 'request' : 'requests'} waiting';
    } else {
      subtitle = accepted == null
          ? 'Use by ${formatDate(donation.expiryDate)}'
          : 'For ${accepted.beneficiary.name}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
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
                child: Icon(
                  donation.category.icon,
                  color: const Color(0xFF1B1B1B),
                ),
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
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            pending > 0 &&
                                donation.status == DonationStatus.available
                            ? const Color(0xFFE65100)
                            : Colors.black54,
                        fontWeight: pending > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? DonationStatusChip(status: donation.status),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets a (simulated) beneficiary ask for a donation.
///
/// Returns the chosen beneficiary's name, or null when cancelled.
Future<String?> showRequestDonationSheet(
  BuildContext context, {
  required DonationRepository repository,
  required Donation donation,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFF5F9F3),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) =>
        _RequestSheet(repository: repository, donation: donation),
  );
}

class _RequestSheet extends StatefulWidget {
  const _RequestSheet({required this.repository, required this.donation});

  final DonationRepository repository;
  final Donation donation;

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final _messageController = TextEditingController();
  Beneficiary? _beneficiary;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _send() {
    final beneficiary = _beneficiary;
    if (beneficiary == null) {
      return;
    }
    widget.repository.requestDonation(
      widget.donation.id,
      beneficiary,
      message: _messageController.text,
    );
    Navigator.of(context).pop(beneficiary.name);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        18 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request ${widget.donation.foodName}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1B1B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Beneficiary accounts are simulated: choose who is asking.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            for (final beneficiary in sampleBeneficiaries)
              _BeneficiaryOption(
                beneficiary: beneficiary,
                selected: _beneficiary?.id == beneficiary.id,
                disabled: widget.repository.hasPendingRequestFrom(
                  widget.donation,
                  beneficiary,
                ),
                onTap: () => setState(() => _beneficiary = beneficiary),
              ),
            const SizedBox(height: 6),
            TextField(
              key: const ValueKey('request-message-field'),
              controller: _messageController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Message (optional), e.g. pick-up time',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                key: const ValueKey('send-request-button'),
                onPressed: _beneficiary == null ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Send request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeneficiaryOption extends StatelessWidget {
  const _BeneficiaryOption({
    required this.beneficiary,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final Beneficiary beneficiary;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? const Color(0xFF2E7D32) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                beneficiaryTypeIcon(beneficiary.type),
                color: disabled ? Colors.black26 : const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      beneficiary.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: disabled
                            ? Colors.black38
                            : const Color(0xFF1B1B1B),
                      ),
                    ),
                    Text(
                      disabled
                          ? 'Already asked'
                          : '${beneficiaryTypeLabel(beneficiary.type)} · '
                                '${beneficiary.area}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
