import 'package:flutter/material.dart';

import '../../home/presentation/home_screen.dart';
import '../../list/presentation/list_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../data/fridge_repository.dart';
import '../domain/food_category.dart';
import '../domain/food_item.dart';
import '../domain/fridge_formatters.dart';
import 'add_food_screen.dart';
import 'food_details_screen.dart';
import 'widgets/name_input_dialog.dart';

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key, this.repository});

  /// Defaults to [FridgeRepository.instance]; injectable for tests.
  final FridgeRepository? repository;

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  int _selectedIndex = 1;
  final _searchController = TextEditingController();
  String _search = '';
  FoodCategory? _categoryFilter;
  FridgeSort _sort = FridgeSort.expiryDate;

  FridgeRepository get _repository =>
      widget.repository ?? FridgeRepository.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _openAddFood() async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => AddFoodScreen(repository: _repository),
      ),
    );
    if (name != null && mounted) {
      _showSnackBar('$name added to your fridge');
    }
  }

  Future<void> _openDetails(FoodItem item) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) =>
            FoodDetailsScreen(repository: _repository, foodId: item.id),
      ),
    );
    if (message != null && mounted) {
      _showSnackBar(message);
    }
  }

  void _deleteFood(FoodItem item) {
    final index = _repository.deleteFood(item.id);
    if (index == -1) {
      return;
    }
    _showSnackBar(
      '${item.name} removed',
      onUndo: () => _repository.restoreFood(item, index),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _search = '');
  }

  void _showSnackBar(String message, {VoidCallback? onUndo}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        action: onUndo == null
            ? null
            : SnackBarAction(
                label: 'Undo',
                textColor: const Color(0xFFB9FBC0),
                onPressed: onUndo,
              ),
      ),
    );
  }

  void _showCategoryManager() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F9F3),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _CategoryManagerSheet(
        repository: _repository,
        onCategoryDeleted: (category) {
          if (_categoryFilter == category) {
            setState(() => _categoryFilter = null);
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
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
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: const Color(0xFF1B1B1B),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'My fridge',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B1B1B),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Manage categories',
                    onPressed: _showCategoryManager,
                    icon: const Icon(Icons.category_rounded),
                    color: const Color(0xFF2E7D32),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListenableBuilder(
                  listenable: _repository,
                  builder: (context, _) => _buildContent(),
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
              MaterialPageRoute(
                builder: (context) => const FoodSaverHomePage(),
              ),
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
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add food',
        onPressed: _openAddFood,
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContent() {
    final now = _repository.now;
    final presentCategories = _presentCategories();
    final filter = presentCategories.contains(_categoryFilter)
        ? _categoryFilter
        : null;
    final results = _repository.query(
      search: _search,
      category: filter,
      sort: _sort,
    );
    final priority = results.where((item) => item.isPriority(now)).toList();
    final fresh = results.where((item) => !item.isPriority(now)).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        _SummaryCard(repository: _repository),
        const SizedBox(height: 18),
        _buildSearchField(),
        if (presentCategories.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildCategoryFilter(presentCategories, filter),
        ],
        const SizedBox(height: 10),
        _buildSortSelector(),
        const SizedBox(height: 18),
        if (_repository.totalCount == 0)
          _EmptyState(
            icon: Icons.kitchen_rounded,
            title: 'Your fridge is empty',
            message: 'Tap + to add the food you have at home.',
            actionLabel: 'Add food',
            onAction: _openAddFood,
          )
        else if (results.isEmpty)
          _EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No food found',
            message: 'Try another name or category.',
            actionLabel: 'Clear filters',
            onAction: () {
              _clearSearch();
              setState(() => _categoryFilter = null);
            },
          )
        else ...[
          if (priority.isNotEmpty) ...[
            _SectionHeader(
              title: 'Use first',
              subtitle:
                  'Expired or expiring within $priorityThresholdDays days',
              count: priority.length,
              color: const Color(0xFFE65100),
            ),
            const SizedBox(height: 12),
            for (final item in priority) ...[
              _buildFoodTile(item, now),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 10),
          ],
          if (fresh.isNotEmpty) ...[
            _SectionHeader(
              title: 'Fresh items',
              count: fresh.length,
              color: const Color(0xFF2E7D32),
            ),
            const SizedBox(height: 12),
            for (final item in fresh) ...[
              _buildFoodTile(item, now),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      key: const ValueKey('fridge-search-field'),
      controller: _searchController,
      onChanged: (value) => setState(() => _search = value),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search food',
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2E7D32)),
        suffixIcon: _search.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: _clearSearch,
                icon: const Icon(Icons.close_rounded),
                color: Colors.black45,
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(
    List<FoodCategory> categories,
    FoodCategory? filter,
  ) {
    Widget chip(String label, FoodCategory? value, {IconData? icon}) {
      final selected = filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          avatar: icon == null
              ? null
              : Icon(icon, size: 16, color: const Color(0xFF1B1B1B)),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() => _categoryFilter = value),
          labelStyle: TextStyle(
            color: selected ? const Color(0xFF1B5E20) : Colors.black54,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFB9FBC0),
          side: BorderSide.none,
          shape: const StadiumBorder(),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('All', null),
          for (final category in categories)
            chip(category.name, category, icon: category.icon),
        ],
      ),
    );
  }

  Widget _buildSortSelector() {
    const labels = {
      FridgeSort.expiryDate: 'Expiry date',
      FridgeSort.name: 'Name',
      FridgeSort.recentlyAdded: 'Recently added',
    };
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const Center(
            child: Padding(
              padding: EdgeInsets.only(right: 10),
              child: Row(
                children: [
                  Icon(Icons.sort_rounded, size: 18, color: Colors.black54),
                  SizedBox(width: 6),
                  Text(
                    'Sort by',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          for (final entry in labels.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: _sort == entry.key,
                showCheckmark: false,
                onSelected: (_) => setState(() => _sort = entry.key),
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: _sort == entry.key ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF2E7D32),
                side: BorderSide.none,
                shape: const StadiumBorder(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFoodTile(FoodItem item, DateTime now) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteFood(item),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFCDD2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFC62828),
        ),
      ),
      child: _FoodTile(item: item, now: now, onTap: () => _openDetails(item)),
    );
  }

  /// Categories used in the fridge, in the repository's order.
  List<FoodCategory> _presentCategories() {
    final used = _repository.items.map((item) => item.category).toSet();
    return [
      for (final category in _repository.categories)
        if (used.contains(category)) category,
    ];
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.repository});

  final FridgeRepository repository;

  @override
  Widget build(BuildContext context) {
    final available = repository.availableCount;
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$available ${available == 1 ? 'ingredient' : 'ingredients'}'
                  ' ready to use',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
              ),
              const Icon(
                Icons.kitchen_rounded,
                size: 48,
                color: Color(0xFF2E7D32),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatPill(
                label: '${repository.totalCount} in stock',
                color: const Color(0xFF2E7D32),
              ),
              _StatPill(
                label: '${repository.priorityCount} to use first',
                color: const Color(0xFFE65100),
              ),
              _StatPill(
                label: '${repository.expiredCount} expired',
                color: const Color(0xFFC62828),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.item, required this.now, required this.onTap});

  final FoodItem item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = item.status(now);
    final color = statusColor(status);

    return Container(
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
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: item.category.color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    item.category.icon,
                    color: const Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B1B1B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${quantityLabel(item)} · ${item.category.name}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground(status),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        daysLeftLabel(item, now),
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatDate(item.expiryDate),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
    this.subtitle,
  });

  final String title;
  final int count;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1B1B),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 36, color: const Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B1B1B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryManagerSheet extends StatelessWidget {
  const _CategoryManagerSheet({
    required this.repository,
    required this.onCategoryDeleted,
  });

  final FridgeRepository repository;
  final ValueChanged<FoodCategory> onCategoryDeleted;

  Future<void> _addCategory(BuildContext context) async {
    final name = await showNameInputDialog(
      context,
      title: 'New category',
      label: 'Category name',
      confirmLabel: 'Create',
      validator: (value) => repository.hasCategoryNamed(value)
          ? 'This category already exists'
          : null,
    );
    if (name != null) {
      repository.addCategory(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: ListenableBuilder(
          listenable: repository,
          builder: (context, _) {
            final categories = repository.categories;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Food categories',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B1B1B),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _addCategory(context),
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Color(0xFF2E7D32),
                        ),
                        label: const Text(
                          'Add',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
                    itemCount: categories.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final count = repository.itemCountForCategory(category);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: category.color,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                category.icon,
                                size: 20,
                                color: const Color(0xFF1B1B1B),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1B1B1B),
                                    ),
                                  ),
                                  Text(
                                    category.isCustom
                                        ? '$count food(s) · Custom'
                                        : '$count food(s)',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (category.isCustom)
                              IconButton(
                                tooltip: 'Delete category',
                                onPressed: () {
                                  repository.removeCategory(category);
                                  onCategoryDeleted(category);
                                },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFFC62828),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
