import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../donations/data/donation_repository.dart';
import '../../donations/domain/beneficiary.dart';
import '../../donations/domain/donation.dart';
import '../../donations/presentation/widgets/donation_widgets.dart';
import '../../profile/data/user_profile_repository.dart';

/// Donations tab of a restaurant: every available donation, with a button to
/// request it. The restaurant is the beneficiary of its own requests.
class RestaurantDonationsTab extends StatefulWidget {
  const RestaurantDonationsTab({
    super.key,
    required this.title,
    required this.emptyMessage,
    this.donations,
    this.profiles,
  });

  final String title;
  final String emptyMessage;

  /// Default to the app-wide instances; injectable for tests.
  final DonationRepository? donations;
  final UserProfileRepository? profiles;

  @override
  State<RestaurantDonationsTab> createState() => _RestaurantDonationsTabState();
}

class _RestaurantDonationsTabState extends State<RestaurantDonationsTab> {
  DonationRepository get _donations =>
      widget.donations ?? DonationRepository.instance;
  UserProfileRepository get _profiles =>
      widget.profiles ?? UserProfileRepository.instance;

  @override
  void initState() {
    super.initState();
    // Donations published after sign-in are only visible after a reload.
    _donations.refresh();
  }

  Beneficiary get _me {
    final profile = _profiles.profile;
    final business = profile?.businessName.trim() ?? '';
    final name = business.isNotEmpty
        ? business
        : (profile?.displayName.trim().isNotEmpty ?? false)
        ? profile!.displayName.trim()
        : 'Restaurant';
    return Beneficiary(
      id: profile?.uid ?? '',
      name: name,
      type: BeneficiaryType.restaurant,
      area: '',
    );
  }

  Future<void> _request(Donation donation) async {
    final message = await showDialog<String>(
      context: context,
      builder: (context) => _RequestDialog(donation: donation),
    );
    if (message == null || !mounted) {
      return;
    }
    try {
      _donations.requestDonation(donation.id, _me, message: message);
      showAppSnackBar(context, 'Request sent for ${donation.foodName}');
    } on StateError catch (error) {
      showAppSnackBar(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _donations.refresh,
      child: ListenableBuilder(
        listenable: Listenable.merge([_donations, _profiles]),
        builder: (context, _) {
          final available = _donations.availableDonations;
          final me = _me;
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
                    key: const ValueKey('restaurant-refresh-button'),
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh',
                    onPressed: _donations.refresh,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (available.isEmpty)
                EmptyCard(
                  icon: Icons.volunteer_activism_outlined,
                  message: widget.emptyMessage,
                )
              else
                for (final donation in available)
                  DonationCard(
                    key: ValueKey('restaurant-donation-${donation.id}'),
                    donation: donation,
                    onTap: () => _request(donation),
                    trailing: _donations.hasPendingRequestFrom(donation, me)
                        ? const Text(
                            'Requested',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          )
                        : TextButton(
                            key: ValueKey('request-${donation.id}'),
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
            ],
          );
        },
      ),
    );
  }
}

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({required this.donation});

  final Donation donation;

  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final donation = widget.donation;
    return AlertDialog(
      title: Text('Request ${donation.foodName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${donationQuantityLabel(donation)} · use by '
            '${donation.expiryDate.day}/${donation.expiryDate.month}/'
            '${donation.expiryDate.year}',
            style: const TextStyle(color: Colors.black54),
          ),
          if (donation.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(donation.description),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('request-message-field'),
            controller: _message,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Message (optional), e.g. pick-up time',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('send-request-button'),
          onPressed: () => Navigator.of(context).pop(_message.text),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
          ),
          child: const Text('Send request'),
        ),
      ],
    );
  }
}
