import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../fridge/domain/food_category.dart';
import '../../fridge/domain/food_item.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../data/goal_repository.dart';

/// Form used by a restaurant or a charity to publish what it needs.
///
/// Pops with the goal title once published.
class CreateGoalScreen extends StatefulWidget {
  const CreateGoalScreen({
    super.key,
    required this.restaurantName,
    this.repository,
  });

  /// Shown to donors on every goal.
  final String restaurantName;

  /// Defaults to [GoalRepository.instance]; injectable for tests.
  final GoalRepository? repository;

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _food = TextEditingController();
  final _title = TextEditingController();
  final _target = TextEditingController();
  final _description = TextEditingController();
  late FoodCategory _category;
  String _unit = 'kg';
  DateTime? _deadline;
  String? _error;

  GoalRepository get _repository =>
      widget.repository ?? GoalRepository.instance;

  @override
  void initState() {
    super.initState();
    _category = _repository.fridge.categoryNamed('Pantry') ?? otherFoodCategory;
  }

  @override
  void dispose() {
    _food.dispose();
    _title.dispose();
    _target.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final today = DateUtils.dateOnly(_repository.now);
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    try {
      final goal = _repository.createGoal(
        restaurantName: widget.restaurantName,
        title: _title.text,
        foodName: _food.text,
        category: _category,
        target: double.parse(_target.text.trim().replaceAll(',', '.')),
        unit: _unit,
        description: _description.text,
        deadline: _deadline,
      );
      Navigator.of(context).pop(goal.title);
    } on ArgumentError catch (error) {
      setState(() => _error = error.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _repository.fridge.categories;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            children: [
              const ScreenHeader(title: 'New goal'),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  'Tell donors what you need. Every gift moves the progress '
                  'bar until the target is reached.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              const SizedBox(height: 20),
              _Field(
                fieldKey: const ValueKey('goal-food-field'),
                controller: _food,
                label: 'Food needed',
                hint: 'e.g. Rice',
                icon: Icons.restaurant_rounded,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the food you need'
                    : null,
              ),
              const SizedBox(height: 14),
              _Field(
                fieldKey: const ValueKey('goal-title-field'),
                controller: _title,
                label: 'Title (optional)',
                hint: 'e.g. Rice for the soup kitchen',
                icon: Icons.flag_outlined,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _Field(
                      fieldKey: const ValueKey('goal-target-field'),
                      controller: _target,
                      label: 'Target',
                      hint: 'e.g. 10',
                      icon: Icons.track_changes_rounded,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      validator: (value) {
                        final number = double.tryParse(
                          (value ?? '').trim().replaceAll(',', '.'),
                        );
                        if (number == null || number <= 0) {
                          return 'Enter a quantity';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('goal-unit-field'),
                      initialValue: _unit,
                      isExpanded: true,
                      // No icon: the field is narrow on phones.
                      decoration: _decoration('Unit', null),
                      items: [
                        for (final unit in foodUnits)
                          DropdownMenuItem(value: unit, child: Text(unit)),
                      ],
                      onChanged: (value) =>
                          setState(() => _unit = value ?? _unit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<FoodCategory>(
                key: const ValueKey('goal-category-field'),
                initialValue: categories.contains(_category)
                    ? _category
                    : categories.first,
                decoration: _decoration('Category', Icons.category_outlined),
                items: [
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(category.icon, size: 18),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 14),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  key: const ValueKey('goal-deadline-field'),
                  onTap: _pickDeadline,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: const Icon(
                    Icons.event_rounded,
                    color: Color(0xFF2E7D32),
                  ),
                  title: Text(
                    _deadline == null
                        ? 'No deadline'
                        : 'Until ${formatDate(_deadline!)}',
                  ),
                  subtitle: const Text('Last day donors can give'),
                  trailing: _deadline == null
                      ? const Icon(Icons.chevron_right_rounded)
                      : IconButton(
                          tooltip: 'Remove the deadline',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _deadline = null),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              _Field(
                fieldKey: const ValueKey('goal-description-field'),
                controller: _description,
                label: 'Why do you need it? (optional)',
                hint: 'e.g. 80 hot meals every evening this week',
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFC62828),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  key: const ValueKey('save-goal-button'),
                  onPressed: _save,
                  icon: const Icon(Icons.campaign_rounded),
                  label: const Text(
                    'Publish goal',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
    );
  }
}

InputDecoration _decoration(String label, IconData? icon, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null
        ? null
        : Icon(icon, color: const Color(0xFF2E7D32)),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: _decoration(label, icon, hint: hint),
    );
  }
}
