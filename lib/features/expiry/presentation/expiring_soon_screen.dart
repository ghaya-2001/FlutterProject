import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../donations/data/donation_repository.dart';
import '../../donations/presentation/create_donation_screen.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../../fridge/presentation/food_details_screen.dart';
import '../../list/data/shopping_list_repository.dart';
import '../../list/domain/shopping_category.dart';
import '../domain/expiry_alerts.dart';

/// Foods that are expired or expire within 7 days, grouped by urgency.
class ExpiringSoonScreen extends StatelessWidget {
  const ExpiringSoonScreen({
    super.key,
    this.fridge,
    this.donations,
    this.shopping,
  });

  /// Default to the app-wide instances; injectable for tests.
  final FridgeRepository? fridge;
  final DonationRepository? donations;
  final ShoppingListRepository? shopping;

  FridgeRepository get _fridge => fridge ?? FridgeRepository.instance;

  DonationRepository get _donations => donations ?? DonationRepository.instance;

  ShoppingListRepository get _shopping =>
      shopping ?? ShoppingListRepository.instance;

  Future<void> _openDetails(BuildContext context, String foodId) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => FoodDetailsScreen(
          repository: _fridge,
          foodId: foodId,
          donationRepository: _donations,
        ),
      ),
    );
    if (message != null && context.mounted) {
      showAppSnackBar(context, message);
    }
  }

  Future<void> _donate(BuildContext context, String foodId) async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) =>
            CreateDonationScreen(repository: _donations, initialFoodId: foodId),
      ),
    );
    if (name != null && context.mounted) {
      showAppSnackBar(context, '$name offered for donation');
    }
  }

  /// Adds an expired food to the current shopping list so it gets replaced.
  void _addToList(BuildContext context, ExpiryAlert alert) {
    final list = _shopping.selectedList ?? _shopping.createList('My list');
    final category =
        _shopping.categoryNamed(alert.item.category.name) ??
        otherShoppingCategory;
    _shopping.addItem(list.id, name: alert.item.name, category: category);
    showAppSnackBar(context, '${alert.item.name} added to "${list.name}"');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _fridge,
          builder: (context, _) {
            final alerts = expiryAlerts(_fridge.items, _fridge.now);
            List<ExpiryAlert> withLevel(ExpiryAlertLevel level) =>
                alerts.where((alert) => alert.level == level).toList();

            final sections = <(String, List<ExpiryAlert>)>[
              ('Expired', withLevel(ExpiryAlertLevel.expired)),
              ('Expires today', withLevel(ExpiryAlertLevel.today)),
              ('Within 3 days', withLevel(ExpiryAlertLevel.threeDays)),
              ('This week', withLevel(ExpiryAlertLevel.sevenDays)),
            ];
            final soonCount = alerts
                .where((alert) => alert.level != ExpiryAlertLevel.expired)
                .length;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              children: [
                const ScreenHeader(title: 'Expiring soon'),
                const SizedBox(height: 18),
                _SummaryCard(soonCount: soonCount),
                if (alerts.isEmpty) ...[
                  const SizedBox(height: 22),
                  const EmptyCard(
                    icon: Icons.check_circle_outline_rounded,
                    message: 'Nothing expires in the next 7 days. Well done!',
                  ),
                ],
                for (final (title, items) in sections)
                  if (items.isNotEmpty) ...[
                    SectionTitle(title),
                    for (final alert in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExpiringTile(
                          alert: alert,
                          now: _fridge.now,
                          onTap: () => _openDetails(context, alert.item.id),
                          onDonate: () => _donate(context, alert.item.id),
                          onAddToList: () => _addToList(context, alert),
                        ),
                      ),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.soonCount});

  final int soonCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE0B2), Color(0xFFFFF8E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.hourglass_bottom_rounded,
              color: Color(0xFFE65100),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  soonCount == 1
                      ? '1 food to use this week'
                      : '$soonCount foods to use this week',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Alerts are sent 7 days and 3 days before, and on the '
                  'expiry day.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiringTile extends StatelessWidget {
  const _ExpiringTile({
    required this.alert,
    required this.now,
    required this.onTap,
    required this.onDonate,
    required this.onAddToList,
  });

  final ExpiryAlert alert;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onDonate;
  final VoidCallback onAddToList;

  @override
  Widget build(BuildContext context) {
    final item = alert.item;
    final color = alertLevelColor(alert.level);
    final isExpired = alert.level == ExpiryAlertLevel.expired;

    return InkWell(
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
                color: item.category.color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.category.icon, color: const Color(0xFF1B1B1B)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${quantityLabel(item)} · ${daysLeftLabel(item, now)}',
                    style: TextStyle(fontSize: 13, color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isExpired
                ? TextButton.icon(
                    onPressed: onAddToList,
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: const Text('Add to list'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                    ),
                  )
                : TextButton.icon(
                    onPressed: onDonate,
                    icon: const Icon(
                      Icons.volunteer_activism_rounded,
                      size: 18,
                    ),
                    label: const Text('Donate'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
