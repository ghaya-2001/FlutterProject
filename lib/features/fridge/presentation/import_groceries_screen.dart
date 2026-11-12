import 'package:flutter/material.dart';

import '../../list/data/shopping_list_repository.dart';
import '../../list/domain/shopping_item.dart';
import '../data/fridge_repository.dart';
import '../domain/food_category.dart';
import '../domain/fridge_formatters.dart';
import '../domain/shelf_life.dart';

const _green = Color(0xFF2E7D32);
const _dark = Color(0xFF1B1B1B);

/// A bought shopping item that can go to the fridge.
class _Grocery {
  _Grocery({
    required this.item,
    required this.listName,
    required this.category,
    required this.expiryDate,
  });

  final ShoppingItem item;
  final String listName;
  final FoodCategory category;
  DateTime expiryDate;
  bool selected = true;
}

/// Moves the groceries bought in the shopping list (Membre 4) to the fridge,
/// with an expiry date suggested from the typical shelf life of each
/// category.
class ImportGroceriesScreen extends StatefulWidget {
  const ImportGroceriesScreen({
    super.key,
    required this.repository,
    this.shoppingRepository,
  });

  final FridgeRepository repository;

  /// Defaults to [ShoppingListRepository.instance].
  final ShoppingListRepository? shoppingRepository;

  /// Bought food items not moved to the fridge yet.
  static int pendingCount(
    FridgeRepository repository,
    ShoppingListRepository shopping,
  ) {
    var count = 0;
    for (final list in shopping.lists) {
      for (final item in list.boughtItems) {
        if (_isFood(item) && !repository.isImported(item.id)) {
          count++;
        }
      }
    }
    return count;
  }

  static bool _isFood(ShoppingItem item) =>
      !nonFoodShoppingCategories.contains(item.category.name);

  @override
  State<ImportGroceriesScreen> createState() => _ImportGroceriesScreenState();
}

class _ImportGroceriesScreenState extends State<ImportGroceriesScreen> {
  late final List<_Grocery> _groceries = _loadGroceries();

  ShoppingListRepository get _shopping =>
      widget.shoppingRepository ?? ShoppingListRepository.instance;

  List<_Grocery> _loadGroceries() {
    final repository = widget.repository;
    final groceries = <_Grocery>[];
    for (final list in _shopping.lists) {
      for (final item in list.boughtItems) {
        if (!ImportGroceriesScreen._isFood(item) ||
            repository.isImported(item.id)) {
          continue;
        }
        final category =
            repository.categoryNamed(item.category.name) ?? otherFoodCategory;
        groceries.add(
          _Grocery(
            item: item,
            listName: list.name,
            category: category,
            expiryDate: suggestedExpiry(
              category,
              item.boughtAt ?? repository.now,
            ),
          ),
        );
      }
    }
    return groceries;
  }

  int get _selectedCount => _groceries.where((g) => g.selected).length;

  Future<void> _pickDate(_Grocery grocery) async {
    final today = DateUtils.dateOnly(widget.repository.now);
    final picked = await showDatePicker(
      context: context,
      initialDate: grocery.expiryDate.isBefore(today)
          ? today
          : grocery.expiryDate,
      firstDate: today,
      lastDate: DateUtils.addDaysToDate(today, 3 * 365),
      helpText: 'Expiry date of ${grocery.item.name}',
    );
    if (picked != null) {
      setState(() => grocery.expiryDate = picked);
    }
  }

  void _import() {
    final selected = _groceries.where((g) => g.selected).toList();
    final added = widget.repository.importGroceries([
      for (final grocery in selected)
        GroceryImport(
          shoppingItemId: grocery.item.id,
          name: grocery.item.name,
          category: grocery.category,
          quantity: grocery.item.quantity.toDouble(),
          unit: grocery.item.unit,
          expiryDate: grocery.expiryDate,
          note: grocery.item.note,
        ),
    ]);
    Navigator.of(context).pop('${added.length} food(s) added to your fridge');
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.repository.now;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 18,
                ),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: _dark,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Bought groceries',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _dark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      'Items checked as bought in your shopping lists. The '
                      'expiry dates are suggested from the usual shelf life: '
                      'tap a date to change it.',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_groceries.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Nothing to add: check items as bought in your '
                        'shopping list first.',
                        style: TextStyle(fontSize: 15, color: Colors.black54),
                      ),
                    )
                  else
                    for (final grocery in _groceries) ...[
                      _GroceryTile(
                        grocery: grocery,
                        daysLabel: _daysLabel(grocery.expiryDate, now),
                        onToggle: (value) =>
                            setState(() => grocery.selected = value),
                        onPickDate: () => _pickDate(grocery),
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
            if (_groceries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    key: const ValueKey('import-groceries-button'),
                    onPressed: _selectedCount == 0 ? null : _import,
                    icon: const Icon(Icons.kitchen_rounded),
                    label: Text(
                      'Add $_selectedCount to my fridge',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _daysLabel(DateTime expiry, DateTime now) {
    final days = DateUtils.dateOnly(expiry)
        .difference(DateUtils.dateOnly(now))
        .inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'in 1 day';
    return 'in $days days';
  }
}

class _GroceryTile extends StatelessWidget {
  const _GroceryTile({
    required this.grocery,
    required this.daysLabel,
    required this.onToggle,
    required this.onPickDate,
  });

  final _Grocery grocery;
  final String daysLabel;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final item = grocery.item;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Checkbox(
            value: grocery.selected,
            activeColor: _green,
            onChanged: (value) => onToggle(value ?? false),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: grocery.category.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(grocery.category.icon, size: 20, color: _dark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                  ),
                ),
                Text(
                  '${item.quantityLabel} · ${grocery.listName}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatDate(grocery.expiryDate),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _green,
                    ),
                  ),
                  Text(
                    daysLabel,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
