import 'package:flutter/material.dart';

import '../../home/presentation/home_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  int _selectedIndex = 2;

  @override
  Widget build(BuildContext context) {
    final items = <_ShoppingItem>[
      _ShoppingItem('Milk', 'Dairy', true),
      _ShoppingItem('Tomatoes', 'Vegetables', false),
      _ShoppingItem('Rice', 'Pantry', false),
      _ShoppingItem('Avocados', 'Fruit', true),
      _ShoppingItem('Pasta', 'Pantry', false),
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
                    'Shopping list',
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
                    colors: [Color(0xFFB9FBC0), Color(0xFFEAFBE8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: const [
                    Expanded(
                      child: Text(
                        'Smart groceries for a greener week',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1B1B),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.list_alt_rounded,
                      size: 48,
                      color: Color(0xFF2E7D32),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Today',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B1B1B),
                ),
              ),
              const SizedBox(height: 12),
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
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: item.isDone
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFE0E0E0),
                              shape: BoxShape.circle,
                            ),
                            child: item.isDone
                                ? const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: item.isDone
                                        ? Colors.black38
                                        : const Color(0xFF1B1B1B),
                                    decoration: item.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
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
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              item.isDone ? 'Bought' : 'Add',
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w700,
                              ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _ShoppingItem {
  const _ShoppingItem(this.name, this.category, this.isDone);

  final String name;
  final String category;
  final bool isDone;
}
