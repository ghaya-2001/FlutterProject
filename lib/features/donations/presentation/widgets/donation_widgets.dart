import 'package:flutter/material.dart';

import '../../../fridge/domain/fridge_formatters.dart';
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
