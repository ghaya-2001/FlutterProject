import 'package:flutter/material.dart';

import '../../donations/data/donation_repository.dart';
import '../../donations/presentation/create_donation_screen.dart';
import '../data/fridge_repository.dart';
import '../domain/food_item.dart';
import '../domain/fridge_formatters.dart';
import 'edit_food_screen.dart';
import 'widgets/consume_dialog.dart';

/// Shows every detail of a food and lets the user consume, edit or delete it.
///
/// Pops with a message for the fridge screen when the food leaves the fridge.
class FoodDetailsScreen extends StatelessWidget {
  const FoodDetailsScreen({
    super.key,
    required this.repository,
    required this.foodId,
    this.donationRepository,
  });

  final FridgeRepository repository;
  final String foodId;

  /// Defaults to [DonationRepository.instance] (Membre 3, "Donate" button).
  final DonationRepository? donationRepository;

  Future<void> _donate(BuildContext context, FoodItem item) async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => CreateDonationScreen(
          repository: donationRepository ?? DonationRepository.instance,
          initialFoodId: item.id,
        ),
      ),
    );
    if (name == null || !context.mounted) {
      return;
    }
    if (repository.itemById(item.id) == null) {
      // Everything was donated: the food left the fridge.
      Navigator.of(context).pop('$name offered for donation');
      return;
    }
    _showSnackBar(context, '$name offered for donation');
  }

  Future<void> _consume(BuildContext context, FoodItem item) async {
    final amount = await showConsumeDialog(context, item);
    if (amount == null || !context.mounted) {
      return;
    }
    final remaining = repository.consume(item.id, amount);
    if (remaining == 0) {
      Navigator.of(context).pop('${item.name} finished and removed');
      return;
    }
    _showSnackBar(
      context,
      '${formatQuantity(amount)} ${item.unit} consumed · '
      '${formatQuantity(remaining)} ${item.unit} left',
    );
  }

  Future<void> _edit(BuildContext context, FoodItem item) async {
    final savedName = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) =>
            EditFoodScreen(repository: repository, item: item),
      ),
    );
    if (savedName != null && context.mounted) {
      _showSnackBar(context, '$savedName updated');
    }
  }

  Future<void> _delete(BuildContext context, FoodItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete food?'),
        content: Text('${item.name} will be removed from your fridge.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Yes, delete',
              style: TextStyle(color: Color(0xFFC62828)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    repository.deleteFood(item.id);
    Navigator.of(context).pop('${item.name} deleted');
  }

  void _showSnackBar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: repository,
          builder: (context, _) {
            final item = repository.itemById(foodId);
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: const Color(0xFF1B1B1B),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Food details',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B1B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (item == null)
                    const _MissingFood()
                  else
                    ..._buildDetails(context, item),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildDetails(BuildContext context, FoodItem item) {
    final now = repository.now;
    final status = item.status(now);
    final color = statusColor(status);

    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [item.category.color, const Color(0xFFE8F5E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                item.category.icon,
                size: 36,
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${quantityLabel(item)} · ${item.category.name}',
                    style: const TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: statusBackground(status),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(
              item.isPriority(now)
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              color: color,
              size: 32,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusTitle(status),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.isPriority(now) && !item.isExpired(now)
                        ? '${daysLeftLabel(item, now)} · consume it in priority'
                        : daysLeftLabel(item, now),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
              icon: Icons.scale_rounded,
              label: 'Quantity available',
              value: quantityLabel(item),
            ),
            _InfoRow(
              icon: Icons.category_rounded,
              label: 'Category',
              value: item.category.name,
            ),
            _InfoRow(
              icon: Icons.event_rounded,
              label: 'Expiry date',
              value: formatDate(item.expiryDate),
            ),
            _InfoRow(
              icon: Icons.add_circle_outline_rounded,
              label: 'Added on',
              value: formatDate(item.addedAt),
            ),
            if (item.note.isNotEmpty)
              _InfoRow(
                icon: Icons.sticky_note_2_outlined,
                label: 'Note',
                value: item.note,
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          key: const ValueKey('consume-button'),
          onPressed: () => _consume(context, item),
          icon: const Icon(Icons.restaurant_rounded),
          label: const Text(
            'Consume',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                key: const ValueKey('edit-food-button'),
                onPressed: () => _edit(context, item),
                icon: const Icon(Icons.edit_rounded),
                label: const Text(
                  'Edit',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                key: const ValueKey('delete-food-button'),
                onPressed: () => _delete(context, item),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text(
                  'Delete',
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
          ),
        ],
      ),
      if (!item.isExpired(now)) ...[
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            key: const ValueKey('donate-food-button'),
            onPressed: () => _donate(context, item),
            icon: const Icon(Icons.volunteer_activism_rounded),
            label: const Text(
              'Donate',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2E7D32),
              backgroundColor: const Color(0xFFE8F5E9),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    ];
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

class _MissingFood extends StatelessWidget {
  const _MissingFood();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Text(
        'This food is no longer in your fridge.',
        style: TextStyle(fontSize: 16, color: Colors.black54),
      ),
    );
  }
}
