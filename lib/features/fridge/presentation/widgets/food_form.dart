import 'package:flutter/material.dart';

import '../../data/fridge_repository.dart';
import '../../domain/food_category.dart';
import '../../domain/food_item.dart';
import '../../domain/fridge_formatters.dart';
import 'name_input_dialog.dart';

typedef FoodFormValues = ({
  String name,
  FoodCategory category,
  double quantity,
  String unit,
  DateTime expiryDate,
  String note,
});

/// Form shared by the Add Food and Edit Food screens.
class FoodForm extends StatefulWidget {
  const FoodForm({
    super.key,
    required this.repository,
    required this.submitLabel,
    required this.submitIcon,
    required this.onSubmit,
    this.initialItem,
  });

  final FridgeRepository repository;
  final String submitLabel;
  final IconData submitIcon;
  final ValueChanged<FoodFormValues> onSubmit;
  final FoodItem? initialItem;

  @override
  State<FoodForm> createState() => _FoodFormState();
}

class _FoodFormState extends State<FoodForm> {
  static const _quickDates = <(String, int)>[
    ('Today', 0),
    ('+3 days', 3),
    ('+1 week', 7),
    ('+2 weeks', 14),
    ('+1 month', 30),
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _noteController;
  late String _unit;
  late FoodCategory _category;
  DateTime? _expiryDate;
  bool _showDateError = false;

  FridgeRepository get _repository => widget.repository;

  DateTime get _today => DateUtils.dateOnly(_repository.now);

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _quantityController = TextEditingController(
      text: formatQuantity(item?.quantity ?? 1),
    );
    _noteController = TextEditingController(text: item?.note ?? '');
    _unit = item?.unit ?? foodUnits.first;
    _category = item?.category ?? _repository.categories.first;
    _expiryDate = item?.expiryDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? get _parsedQuantity =>
      double.tryParse(_quantityController.text.trim().replaceAll(',', '.'));

  void _changeQuantity(int direction) {
    final step = quantityStepFor(_unit);
    final current = _parsedQuantity ?? 0;
    var next = current + step * direction;
    if (next < step) {
      next = step;
    }
    setState(() {
      _quantityController.text = formatQuantity(next);
    });
  }

  void _selectUnit(String unit) {
    if (unit == _unit) {
      return;
    }
    setState(() {
      _unit = unit;
      // Reset to a sensible default amount for the new unit.
      final step = quantityStepFor(unit);
      _quantityController.text = formatQuantity(step < 1 ? 1 : step);
    });
  }

  Future<void> _pickDate() async {
    final initial = _expiryDate ?? _today.add(const Duration(days: 7));
    final first = initial.isBefore(_today) ? initial : _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: _today.add(const Duration(days: 365 * 5)),
      helpText: 'Expiry date',
    );
    if (picked != null && mounted) {
      setState(() {
        _expiryDate = DateUtils.dateOnly(picked);
        _showDateError = false;
      });
    }
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

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    setState(() {
      _showDateError = _expiryDate == null;
    });
    final expiryDate = _expiryDate;
    if (!isValid || expiryDate == null) {
      return;
    }
    widget.onSubmit((
      name: _nameController.text.trim(),
      category: _category,
      quantity: _parsedQuantity!,
      unit: _unit,
      expiryDate: expiryDate,
      note: _noteController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final expiryDate = _expiryDate;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Food name'),
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('food-name-field'),
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Please enter a food name';
              }
              return null;
            },
            decoration: _inputDecoration(
              hint: 'e.g. Spinach',
              icon: Icons.restaurant_rounded,
            ),
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
                      onSelected: () => setState(() => _category = category),
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
          const _SectionLabel('Quantity'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('quantity-decrease'),
                  onPressed: () => _changeQuantity(-1),
                  icon: const Icon(Icons.remove_rounded),
                  color: const Color(0xFF2E7D32),
                ),
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('quantity-field'),
                    controller: _quantityController,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B1B1B),
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      suffixText: _unit,
                    ),
                    validator: (_) {
                      final quantity = _parsedQuantity;
                      if (quantity == null || quantity <= 0) {
                        return 'Enter a quantity above 0';
                      }
                      return null;
                    },
                  ),
                ),
                IconButton(
                  key: const ValueKey('quantity-increase'),
                  onPressed: () => _changeQuantity(1),
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
              for (final unit in foodUnits)
                _SelectableChip(
                  label: unit,
                  selected: unit == _unit,
                  onSelected: () => _selectUnit(unit),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Expiry date'),
          const SizedBox(height: 10),
          InkWell(
            key: const ValueKey('expiry-date-field'),
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _showDateError
                      ? const Color(0xFFC62828)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      expiryDate == null
                          ? 'Choose a date'
                          : formatDate(expiryDate),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: expiryDate == null
                            ? FontWeight.w400
                            : FontWeight.w700,
                        color: expiryDate == null
                            ? Colors.black45
                            : const Color(0xFF1B1B1B),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF2E7D32),
                  ),
                ],
              ),
            ),
          ),
          if (_showDateError)
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 8),
              child: Text(
                'Please choose an expiry date',
                style: TextStyle(color: Color(0xFFC62828), fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, days) in _quickDates)
                _SelectableChip(
                  label: label,
                  selected:
                      expiryDate != null &&
                      expiryDate == _today.add(Duration(days: days)),
                  onSelected: () => setState(() {
                    _expiryDate = _today.add(Duration(days: days));
                    _showDateError = false;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Note (optional)'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _noteController,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: _inputDecoration(
              hint: 'Opened, homemade, shelf...',
              icon: Icons.sticky_note_2_outlined,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              key: const ValueKey('save-food-button'),
              onPressed: _submit,
              icon: Icon(widget.submitIcon),
              label: Text(
                widget.submitLabel,
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
