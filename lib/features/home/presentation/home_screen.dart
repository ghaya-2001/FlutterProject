import 'package:flutter/material.dart';

import '../../chatbot/presentation/chatbot_screen.dart';
import '../../donations/data/donation_repository.dart';
import '../../donations/presentation/donations_screen.dart';
import '../../expiry/domain/expiry_alerts.dart';
import '../../expiry/presentation/expiring_soon_screen.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../../fridge/presentation/food_details_screen.dart';
import '../../fridge/presentation/fridge_screen.dart';
import '../../list/presentation/list_screen.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class FoodSaverHomePage extends StatefulWidget {
  const FoodSaverHomePage({super.key});

  @override
  State<FoodSaverHomePage> createState() => _FoodSaverHomePageState();
}

class _FoodSaverHomePageState extends State<FoodSaverHomePage> {
  int _selectedIndex = 0;

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Good morning,',
                          style: TextStyle(color: Colors.black54, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Maya',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B1B1B),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      key: const ValueKey('home-notifications-button'),
                      onTap: () => _open(const NotificationsScreen()),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListenableBuilder(
                          listenable: NotificationRepository.instance,
                          builder: (context, _) {
                            final unread =
                                NotificationRepository.instance.unreadCount;
                            return Badge(
                              isLabelVisible: unread > 0,
                              label: Text('$unread'),
                              backgroundColor: const Color(0xFFE65100),
                              child: const Icon(
                                Icons.notifications_none,
                                color: Color(0xFF2E7D32),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3F2E7D32),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Food saved',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '12 meals protected this week',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'You reduced waste and kept food fresh longer.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.eco_outlined,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Quick actions',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        title: 'Fridge',
                        subtitle: '7 items',
                        icon: Icons.kitchen,
                        color: Color(0xFFB2DFDB),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: _ActionCard(
                        title: 'Recipes',
                        subtitle: '3 ideas',
                        icon: Icons.restaurant_menu,
                        color: Color(0xFFFFE082),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ListenableBuilder(
                        listenable: DonationRepository.instance,
                        builder: (context, _) {
                          final requests =
                              DonationRepository.instance.pendingRequestCount;
                          return _ActionCard(
                            title: 'Donations',
                            subtitle: requests == 0
                                ? 'Share your food'
                                : '$requests new '
                                      '${requests == 1 ? 'request' : 'requests'}',
                            icon: Icons.volunteer_activism_rounded,
                            color: const Color(0xFFC8E6C9),
                            onTap: () => _open(const DonationsScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _ActionCard(
                        title: 'Assistant',
                        subtitle: 'Ask a question',
                        icon: Icons.chat_bubble_outline_rounded,
                        color: const Color(0xFFBBDEFB),
                        onTap: () => _open(const ChatbotScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  // Live data from the fridge (Membre 4: Expiring soon).
                  child: ListenableBuilder(
                    listenable: FridgeRepository.instance,
                    builder: (context, _) {
                      final fridge = FridgeRepository.instance;
                      final soon = expiringSoon(fridge.items, fridge.now);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Expiring soon',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B1B1B),
                                ),
                              ),
                              TextButton(
                                key: const ValueKey('home-expiring-view-all'),
                                onPressed: () =>
                                    _open(const ExpiringSoonScreen()),
                                child: const Text(
                                  'View all',
                                  style: TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (soon.isEmpty)
                            const Text(
                              'Nothing expires in the next 7 days.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          for (final item in soon.take(3)) ...[
                            _FoodItemRow(
                              name: item.name,
                              detail: daysLeftLabel(item, fridge.now),
                              color: statusColor(item.status(fridge.now)),
                              onPressed: () => _open(
                                FoodDetailsScreen(
                                  repository: fridge,
                                  foodId: item.id,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });

          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const FridgeScreen()),
            );
          }

          if (index == 2) {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (context) => const ListScreen()));
          }

          if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            label: 'Fridge',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            label: 'List',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF1B1B1B)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1B1B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodItemRow extends StatelessWidget {
  const _FoodItemRow({
    required this.name,
    required this.detail,
    required this.color,
    this.onPressed,
  });

  final String name;
  final String detail;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B1B1B),
                ),
              ),
              Text(
                detail,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onPressed ?? () {},
          child: const Text(
            'Use now',
            style: TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
