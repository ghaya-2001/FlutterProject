import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../donations/data/donation_repository.dart';
import '../../donations/presentation/donation_details_screen.dart';
import '../../expiry/domain/expiry_alerts.dart';
import '../../expiry/presentation/expiring_soon_screen.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../fridge/presentation/food_details_screen.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    this.repository,
    this.fridge,
    this.donations,
  });

  /// Default to the app-wide instances; injectable for tests.
  final NotificationRepository? repository;
  final FridgeRepository? fridge;
  final DonationRepository? donations;

  NotificationRepository get _repository =>
      repository ?? NotificationRepository.instance;

  FridgeRepository get _fridge => fridge ?? FridgeRepository.instance;

  DonationRepository get _donations => donations ?? DonationRepository.instance;

  Future<void> _open(BuildContext context, AppNotification notification) async {
    _repository.markRead(notification.id);
    final Widget screen;
    if (notification.type == AppNotificationType.donation &&
        notification.donationId != null) {
      screen = DonationDetailsScreen(
        repository: _donations,
        donationId: notification.donationId!,
      );
    } else if (notification.foodId != null) {
      screen = FoodDetailsScreen(
        repository: _fridge,
        foodId: notification.foodId!,
        donationRepository: _donations,
      );
    } else {
      return;
    }
    final message = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (context) => screen));
    if (message != null && context.mounted) {
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
            final donationEvents = _repository.donationNotifications;
            final expiry = _repository.expiryNotifications;
            final unread = _repository.unreadCount;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              children: [
                ScreenHeader(
                  title: 'Notifications',
                  actions: [
                    if (unread > 0)
                      HeaderIconButton(
                        icon: Icons.done_all_rounded,
                        tooltip: 'Mark all as read',
                        onPressed: _repository.markAllRead,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _InfoCard(
                  unread: unread,
                  onOpenExpiring: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ExpiringSoonScreen(
                        fridge: _fridge,
                        donations: _donations,
                      ),
                    ),
                  ),
                ),
                if (donationEvents.isNotEmpty) ...[
                  const SectionTitle('Donations'),
                  for (final notification in donationEvents)
                    _NotificationTile(
                      notification: notification,
                      onTap: () => _open(context, notification),
                    ),
                ],
                const SectionTitle('Expiry alerts'),
                if (expiry.isEmpty)
                  const EmptyCard(
                    icon: Icons.notifications_off_outlined,
                    message: 'No food is close to its expiry date.',
                  )
                else
                  for (final notification in expiry)
                    _NotificationTile(
                      notification: notification,
                      onTap: () => _open(context, notification),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.unread, required this.onOpenExpiring});

  final int unread;
  final VoidCallback onOpenExpiring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            unread == 0
                ? 'You are all caught up'
                : unread == 1
                ? '1 unread notification'
                : '$unread unread notifications',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Food Saver reminds you 7 days and 3 days before a food expires, '
            'and on the expiry day.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenExpiring,
            icon: const Icon(Icons.hourglass_bottom_rounded, size: 18),
            label: const Text('See expiring soon'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final level = notification.level;
    final color = level != null
        ? alertLevelColor(level)
        : const Color(0xFF1565C0);
    final background = level != null
        ? alertLevelBackground(level)
        : const Color(0xFFE3F2FD);
    final icon = notification.type == AppNotificationType.donation
        ? Icons.volunteer_activism_rounded
        : level == ExpiryAlertLevel.expired
        ? Icons.error_outline_rounded
        : Icons.hourglass_bottom_rounded;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: notification.isRead
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: const Color(0xFF1B1B1B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  key: ValueKey('unread-${notification.id}'),
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(left: 8, top: 4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
