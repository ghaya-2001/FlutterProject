import 'package:flutter/material.dart';

import '../../donations/data/donation_repository.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../profile/data/user_profile_repository.dart';

/// Puts the donations accepted for this restaurant into its stock.
///
/// The admin accepts on their own phone and cannot write in the restaurant's
/// fridge, so the restaurant's phone does it when it sees the accepted
/// request. Each donation is added only once (its id is remembered in the
/// fridge's imported ids, saved in Firestore).
class DonationStockReceiver extends StatefulWidget {
  const DonationStockReceiver({
    super.key,
    required this.donations,
    required this.fridge,
    required this.profiles,
    required this.child,
  });

  final DonationRepository donations;
  final FridgeRepository fridge;
  final UserProfileRepository profiles;
  final Widget child;

  @override
  State<DonationStockReceiver> createState() => _DonationStockReceiverState();
}

class _DonationStockReceiverState extends State<DonationStockReceiver> {
  Listenable get _sources =>
      Listenable.merge([widget.donations, widget.fridge, widget.profiles]);

  @override
  void initState() {
    super.initState();
    _sources.addListener(_receive);
    // Not during the build: the stock screens listen to the fridge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _receive();
      }
    });
  }

  @override
  void dispose() {
    _sources.removeListener(_receive);
    super.dispose();
  }

  void _receive() {
    final uid = widget.profiles.profile?.uid;
    // Wait for the fridge to know what it already received.
    if (uid == null || widget.fridge.isLoading) {
      return;
    }
    final groceries = [
      for (final donation in widget.donations.acceptedFor(uid))
        if (!widget.fridge.isImported('donation-${donation.id}'))
          GroceryImport(
            shoppingItemId: 'donation-${donation.id}',
            name: donation.foodName,
            category: donation.category,
            quantity: donation.quantity,
            unit: donation.unit,
            expiryDate: donation.expiryDate,
            note: 'Received as a donation',
          ),
    ];
    if (groceries.isNotEmpty) {
      widget.fridge.importGroceries(groceries);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
