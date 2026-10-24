import 'package:flutter/material.dart';

import '../../fridge/presentation/fridge_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../data/shopping_list_repository.dart';
import '../domain/shopping_category.dart';
import '../domain/shopping_item.dart';
import '../domain/shopping_list.dart';
import 'add_item_screen.dart';
import 'widgets/name_input_dialog.dart';

enum _ListAction {
  newList,
  renameList,
  deleteList,
  manageCategories,
  markAllBought,
  clearBought,
}

class ListScreen extends StatefulWidget {
  const ListScreen({super.key, this.repository});

  /// Defaults to [ShoppingListRepository.instance]; injectable for tests.
  final ShoppingListRepository? repository;

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  int _selectedIndex = 2;
  ShoppingCategory? _categoryFilter;

  ShoppingListRepository get _repository =>
      widget.repository ?? ShoppingListRepository.instance;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _openAddItem(ShoppingList list, {ShoppingItem? item}) async {
    final savedName = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => AddItemScreen(
          repository: _repository,
          listId: list.id,
          initialItem: item,
        ),
      ),
    );
    if (savedName == null || !mounted) {
      return;
    }
    _showSnackBar(
      item == null ? '$savedName added to ${list.name}' : '$savedName updated',
    );
  }

  Future<void> _createList() async {
    final name = await showNameInputDialog(
      context,
      title: 'New shopping list',
      label: 'List name',
      confirmLabel: 'Create',
      validator: (value) => _repository.hasListNamed(value)
          ? 'A list with this name already exists'
          : null,
    );
    if (name == null || !mounted) {
      return;
    }
    _repository.createList(name);
    setState(() => _categoryFilter = null);
    _showSnackBar('List "$name" created');
  }

  Future<void> _renameList(ShoppingList list) async {
    final name = await showNameInputDialog(
      context,
      title: 'Rename list',
      label: 'List name',
      confirmLabel: 'Save',
      initialValue: list.name,
      validator: (value) => _repository.hasListNamed(value, exceptId: list.id)
          ? 'A list with this name already exists'
          : null,
    );
    if (name == null || !mounted) {
      return;
    }
    _repository.renameList(list.id, name);
  }

  Future<void> _deleteList(ShoppingList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete list?'),
        content: Text(
          '"${list.name}" and its ${list.totalCount} item(s) will be removed.',
        ),
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
    if (confirmed != true || !mounted) {
      return;
    }
    _repository.deleteList(list.id);
    setState(() => _categoryFilter = null);
    _showSnackBar('List "${list.name}" deleted');
  }

  void _deleteItem(ShoppingList list, ShoppingItem item) {
    final index = _repository.removeItem(list.id, item.id);
    if (index == -1) {
      return;
    }
    _showSnackBar(
      '${item.name} removed',
      onUndo: () => _repository.restoreItem(list.id, item, index),
    );
  }

  void _clearBought(ShoppingList list) {
    final removed = _repository.clearBought(list.id);
    if (removed.isEmpty) {
      return;
    }
    _showSnackBar(
      '${removed.length} bought item(s) cleared',
      onUndo: () {
        for (final item in removed) {
          _repository.restoreItem(list.id, item, list.items.length);
        }
      },
    );
  }

  void _onMenuAction(_ListAction action, ShoppingList? list) {
    switch (action) {
      case _ListAction.newList:
        _createList();
      case _ListAction.renameList:
        if (list != null) _renameList(list);
      case _ListAction.deleteList:
        if (list != null) _deleteList(list);
      case _ListAction.manageCategories:
        _showCategoryManager();
      case _ListAction.markAllBought:
        if (list != null) _repository.markAllBought(list.id);
      case _ListAction.clearBought:
        if (list != null) _clearBought(list);
    }
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
    return ListenableBuilder(
      listenable: _repository,
      builder: (context, _) {
        final list = _repository.selectedList;

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
                          'Shopping list',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B1B1B),
                          ),
                        ),
                      ),
                      _buildMenu(list),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: list == null
                        ? _buildNoListState()
                        : _buildListContent(list),
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

              if (index == 1) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const FridgeScreen()),
                );
              }

              if (index == 3) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: 'Home',
              ),
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
            tooltip: list == null ? 'New list' : 'Add item',
            onPressed: list == null ? _createList : () => _openAddItem(list),
            backgroundColor: const Color(0xFF2E7D32),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildMenu(ShoppingList? list) {
    return PopupMenuButton<_ListAction>(
      tooltip: 'List options',
      icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF1B1B1B)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (action) => _onMenuAction(action, list),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _ListAction.newList,
          child: _MenuRow(icon: Icons.playlist_add_rounded, label: 'New list'),
        ),
        if (list != null)
          const PopupMenuItem(
            value: _ListAction.renameList,
            child: _MenuRow(icon: Icons.edit_rounded, label: 'Rename list'),
          ),
        const PopupMenuItem(
          value: _ListAction.manageCategories,
          child: _MenuRow(
            icon: Icons.category_rounded,
            label: 'Manage categories',
          ),
        ),
        if (list != null && list.remainingCount > 0)
          const PopupMenuItem(
            value: _ListAction.markAllBought,
            child: _MenuRow(
              icon: Icons.done_all_rounded,
              label: 'Mark all as bought',
            ),
          ),
        if (list != null && list.boughtCount > 0)
          const PopupMenuItem(
            value: _ListAction.clearBought,
            child: _MenuRow(
              icon: Icons.cleaning_services_rounded,
              label: 'Clear bought items',
            ),
          ),
        if (list != null)
          const PopupMenuItem(
            value: _ListAction.deleteList,
            child: _MenuRow(
              icon: Icons.delete_outline_rounded,
              label: 'Delete list',
              color: Color(0xFFC62828),
            ),
          ),
      ],
    );
  }

  Widget _buildNoListState() {
    return _EmptyState(
      icon: Icons.playlist_add_rounded,
      title: 'No shopping list yet',
      message: 'Create a list to start planning your groceries.',
      actionLabel: 'Create a list',
      onAction: _createList,
    );
  }

  Widget _buildListContent(ShoppingList list) {
    final presentCategories = _presentCategories(list);
    final filter = presentCategories.contains(_categoryFilter)
        ? _categoryFilter
        : null;

    bool matches(ShoppingItem item) =>
        filter == null || item.category == filter;

    final pending = list.pendingItems.where(matches).toList();
    final bought = list.boughtItems.where(matches).toList()
      ..sort(
        (a, b) =>
            (b.boughtAt ?? b.createdAt).compareTo(a.boughtAt ?? a.createdAt),
      );

    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        _buildListSelector(list),
        const SizedBox(height: 16),
        _SummaryCard(list: list),
        if (presentCategories.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildCategoryFilter(presentCategories, filter),
        ],
        const SizedBox(height: 22),
        if (list.items.isEmpty)
          _EmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'Your list is empty',
            message: 'Tap + to add your first item.',
            actionLabel: 'Add item',
            onAction: () => _openAddItem(list),
          )
        else ...[
          _SectionHeader(title: 'To buy', count: pending.length),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            const _AllDoneCard()
          else
            ..._buildPendingGroups(list, pending),
          if (bought.isNotEmpty) ...[
            const SizedBox(height: 22),
            _SectionHeader(
              title: 'Bought',
              count: bought.length,
              trailing: TextButton(
                onPressed: () => _clearBought(list),
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final item in bought) ...[
              _buildItemTile(list, item),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ],
    );
  }

  Widget _buildListSelector(ShoppingList selected) {
    final lists = _repository.lists;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final list in lists) ...[
            ChoiceChip(
              label: Text('${list.name} (${list.remainingCount})'),
              selected: list.id == selected.id,
              showCheckmark: false,
              onSelected: (_) {
                _repository.selectList(list.id);
                setState(() => _categoryFilter = null);
              },
              labelStyle: TextStyle(
                color: list.id == selected.id
                    ? Colors.white
                    : const Color(0xFF1B1B1B),
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF2E7D32),
              side: BorderSide.none,
              shape: const StadiumBorder(),
            ),
            const SizedBox(width: 8),
          ],
          ActionChip(
            onPressed: _createList,
            avatar: const Icon(
              Icons.add_rounded,
              size: 18,
              color: Color(0xFF2E7D32),
            ),
            label: const Text('New list'),
            labelStyle: const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: const Color(0xFFE8F5E9),
            side: BorderSide.none,
            shape: const StadiumBorder(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(
    List<ShoppingCategory> categories,
    ShoppingCategory? filter,
  ) {
    Widget chip(String label, ShoppingCategory? value, {IconData? icon}) {
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

  List<Widget> _buildPendingGroups(
    ShoppingList list,
    List<ShoppingItem> pending,
  ) {
    final widgets = <Widget>[];
    for (final category in _orderedCategories(pending)) {
      final items = pending.where((item) => item.category == category).toList();
      widgets.add(_CategoryHeader(category: category, count: items.length));
      widgets.add(const SizedBox(height: 10));
      for (final item in items) {
        widgets.add(_buildItemTile(list, item));
        widgets.add(const SizedBox(height: 12));
      }
      widgets.add(const SizedBox(height: 6));
    }
    return widgets;
  }

  Widget _buildItemTile(ShoppingList list, ShoppingItem item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteItem(list, item),
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
      child: _ShoppingItemTile(
        item: item,
        onToggle: () => _repository.toggleBought(list.id, item.id),
        onEdit: () => _openAddItem(list, item: item),
        onDelete: () => _deleteItem(list, item),
      ),
    );
  }

  /// Categories used by [list], in the order of the repository's categories.
  List<ShoppingCategory> _presentCategories(ShoppingList list) =>
      _orderedCategories(list.items);

  List<ShoppingCategory> _orderedCategories(List<ShoppingItem> items) {
    final used = items.map((item) => item.category).toSet();
    final ordered = [
      for (final category in _repository.categories)
        if (used.contains(category)) category,
    ];
    for (final category in used) {
      if (!ordered.contains(category)) {
        ordered.add(category);
      }
    }
    return ordered;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
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
              Icon(Icons.list_alt_rounded, size: 48, color: Color(0xFF2E7D32)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  list.isCompleted
                      ? 'Everything is bought!'
                      : '${list.remainingCount} item(s) left to buy',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
              ),
              Text(
                '${list.boughtCount}/${list.totalCount} bought',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: list.progress,
              minHeight: 10,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  const _ShoppingItemTile({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = [item.quantityLabel, item.category.name].join(' · ');

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
          onTap: onEdit,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 4, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: item.isBought
                      ? 'Mark as not bought'
                      : 'Mark as bought',
                  onPressed: onToggle,
                  icon: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: item.isBought
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE0E0E0),
                      shape: BoxShape.circle,
                    ),
                    child: item.isBought
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: item.isBought
                        ? const Color(0xFFF0F0F0)
                        : item.category.color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    item.category.icon,
                    size: 22,
                    color: item.isBought
                        ? Colors.black38
                        : const Color(0xFF1B1B1B),
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
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: item.isBought
                              ? Colors.black38
                              : const Color(0xFF1B1B1B),
                          decoration: item.isBought
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      if (item.note.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete item',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.black38,
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
    this.trailing,
  });

  final String title;
  final int count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B1B1B),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category, required this.count});

  final ShoppingCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: category.color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          category.name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: const TextStyle(fontSize: 13, color: Colors.black45),
        ),
      ],
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.celebration_rounded, color: Color(0xFF2E7D32), size: 32),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'All done! Everything on this list has been bought.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B1B1B),
              ),
            ),
          ),
        ],
      ),
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

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF1B1B1B),
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _CategoryManagerSheet extends StatelessWidget {
  const _CategoryManagerSheet({
    required this.repository,
    required this.onCategoryDeleted,
  });

  final ShoppingListRepository repository;
  final ValueChanged<ShoppingCategory> onCategoryDeleted;

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
                          'Categories',
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
                                        ? '$count item(s) · Custom'
                                        : '$count item(s)',
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
