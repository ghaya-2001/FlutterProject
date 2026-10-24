import 'package:flutter/material.dart';

import '../data/shopping_list_repository.dart';
import '../domain/shopping_category.dart';
import '../domain/shopping_item.dart';
import 'widgets/name_input_dialog.dart';

/// Screen used to add a new item to a shopping list, or to edit an existing
/// one when [initialItem] is provided.
class AddItemScreen extends StatefulWidget {
  const AddItemScreen({
    super.key,
    required this.repository,
    required this.listId,
    this.initialItem,
  });

  final ShoppingListRepository repository;
  final String listId;
  final ShoppingItem? initialItem;

  bool get isEditing => initialItem != null;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  static const _maxQuantity = 99;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late int _quantity;
  late String _unit;
  late ShoppingCategory _category;

  ShoppingListRepository get _repository => widget.repository;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _noteController = TextEditingController(text: item?.note ?? '');
    _quantity = item?.quantity ?? 1;
    _unit = item?.unit ?? shoppingUnits.first;
    _category = item?.category ?? _repository.categories.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _createCategory() async {
    final name = await showNameInputDialog(
      context,
      title: 'New category',
      label: 'Category name',
      confirmLabel: 'Create',
      validator: (value) => _repository.hasCategoryNamed(value)
          ? 'This category already exists'
          : null,
    );
    if (name == null || !mounted) {
      return;
    }
    final category = _repository.addCategory(name);
    setState(() {
      _category = category;
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final name = _nameController.text.trim();
    final note = _noteController.text.trim();
    final initialItem = widget.initialItem;

    if (initialItem != null) {
      _repository.updateItem(
        widget.listId,
        initialItem.copyWith(
          name: name,
          category: _category,
          quantity: _quantity,
          unit: _unit,
          note: note,
        ),
      );
    } else {
      _repository.addItem(
        widget.listId,
        name: name,
        category: _category,
        quantity: _quantity,
        unit: _unit,
        note: note,
      );
    }

    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final listName = _repository.listById(widget.listId)?.name ?? '';

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                    Text(
                      widget.isEditing ? 'Edit item' : 'Add item',
                      style: const TextStyle(
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
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isEditing
                                  ? 'Updating item in'
                                  : 'Adding to',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              listName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B1B1B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 44,
                        color: Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Item name'),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('item-name-field'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Please enter an item name';
                    }
                    return null;
                  },
                  decoration: _inputDecoration(
                    hint: 'e.g. Tomatoes',
                    icon: Icons.shopping_bag_outlined,
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionLabel('Quantity'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('quantity-decrease'),
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        icon: const Icon(Icons.remove_rounded),
                        color: const Color(0xFF2E7D32),
                      ),
                      Expanded(
                        child: Text(
                          '$_quantity',
                          key: const ValueKey('quantity-value'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B1B1B),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('quantity-increase'),
                        onPressed: _quantity < _maxQuantity
                            ? () => setState(() => _quantity++)
                            : null,
                        icon: const Icon(Icons.add_rounded),
                        color: const Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final unit in shoppingUnits)
                      _SelectableChip(
                        label: unit,
                        selected: unit == _unit,
                        onSelected: () => setState(() => _unit = unit),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                const _SectionLabel('Category'),
                const SizedBox(height: 10),
                ListenableBuilder(
                  listenable: _repository,
                  builder: (context, _) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in _repository.categories)
                          _SelectableChip(
                            label: category.name,
                            icon: category.icon,
                            iconBackground: category.color,
                            selected: category == _category,
                            onSelected: () =>
                                setState(() => _category = category),
                          ),
                        ActionChip(
                          onPressed: _createCategory,
                          avatar: const Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: Color(0xFF2E7D32),
                          ),
                          label: const Text('New category'),
                          labelStyle: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w700,
                          ),
                          backgroundColor: const Color(0xFFE8F5E9),
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                const _SectionLabel('Note (optional)'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    hint: 'Brand, size, organic...',
                    icon: Icons.sticky_note_2_outlined,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    key: const ValueKey('save-item-button'),
                    onPressed: _save,
                    icon: Icon(
                      widget.isEditing
                          ? Icons.check_rounded
                          : Icons.add_shopping_cart_rounded,
                    ),
                    label: Text(
                      widget.isEditing ? 'Save changes' : 'Add to list',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1B1B1B),
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.iconBackground,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;
  final Color? iconBackground;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      avatar: icon == null
          ? null
          : CircleAvatar(
              backgroundColor: iconBackground,
              child: Icon(icon, size: 14, color: const Color(0xFF1B1B1B)),
            ),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF1B5E20) : const Color(0xFF1B1B1B),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFB9FBC0),
      side: BorderSide(
        color: selected ? const Color(0xFF2E7D32) : Colors.transparent,
      ),
      shape: const StadiumBorder(),
    );
  }
}
