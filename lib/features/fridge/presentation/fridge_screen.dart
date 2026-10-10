import 'package:flutter/material.dart';

import '../../home/presentation/home_screen.dart';
import '../../list/presentation/list_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    final items = <_FridgeItem>[
      _FridgeItem('Spinach', 'Fresh', '2 days left', const Color(0xFF8BC34A)),
      _FridgeItem('Yogurt', 'Dairy', 'Today', const Color(0xFFFFCC80)),
      _FridgeItem('Tomatoes', 'Vegetables', '3 days left', const Color(0xFFFFAB91)),
      _FridgeItem('Milk', 'Dairy', '5 days left', const Color(0xFFB3E5FC)),
      _FridgeItem('Lemon', 'Fruit', '1 week left', const Color(0xFFFFF59D)),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
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
                  const Text(
                    'My fridge',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE0F7FA), Color(0xFFE8F5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: const [
                    Expanded(
                      child: Text(
                        '7 ingredients ready to use',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1B1B),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.kitchen_rounded,
                      size: 48,
                      color: Color(0xFF2E7D32),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Fresh items',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B1B1B),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0B000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.eco_rounded,
                              color: Color(0xFF1B1B1B),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1B1B1B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.category,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            item.daysLeft,
                            style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });

          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const FoodSaverHomePage()),
            );
          }

          if (index == 2) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const ListScreen()),
            );
          }

          if (index == 3) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.kitchen_outlined), label: 'Fridge'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'List'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _FridgeItem {
  const _FridgeItem(this.name, this.category, this.daysLeft, this.color);

  final String name;
  final String category;
  final String daysLeft;
  final Color color;
}
