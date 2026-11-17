import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../fridge/domain/food_item.dart';
import '../../../fridge/domain/fridge_formatters.dart';
import '../../../profile/data/user_profile_repository.dart';
import '../../data/goal_repository.dart';
import '../../domain/donation_goal.dart';
import 'goal_widgets.dart';

/// Lets a user give to [goal], from a matching fridge food or with food that
/// is not in the app. Returns the message to show, or null if cancelled.
Future<String?> showContributeSheet(
  BuildContext context, {
  required GoalRepository repository,
  required DonationGoal goal,
  String? initialFoodId,
  UserProfileRepository? profiles,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFF5F9F3),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _ContributeSheet(
      repository: repository,
      goalId: goal.id,
      initialFoodId: initialFoodId,
      donorName: _donorName(profiles ?? UserProfileRepository.instance),
    ),
  );
}

String _donorName(UserProfileRepository profiles) {
  final name = profiles.profile?.displayName.trim() ?? '';
  return name.isEmpty ? 'A donor' : name;
}

class _ContributeSheet extends StatefulWidget {
  const _ContributeSheet({
    required this.repository,
    required this.goalId,
    required this.donorName,
    this.initialFoodId,
  });

  final GoalRepository repository;
  final String goalId;
  final String donorName;
  final String? initialFoodId;

  @override
  State<_ContributeSheet> createState() => _ContributeSheetState();
}

class _ContributeSheetState extends State<_ContributeSheet> {
  final _quantity = TextEditingController();

  /// Fridge food chosen, null for "food not in my fridge".
  String? _foodId;
  String? _error;

  GoalRepository get _repository => widget.repository;

  @override
  void initState() {
    super.initState();
    final goal = _repository.goalById(widget.goalId)!;
    final foods = _repository.fridgeFoodsFor(goal);
    if (widget.initialFoodId != null &&
        foods.any((food) => food.id == widget.initialFoodId)) {
      _foodId = widget.initialFoodId;
    } else if (foods.isNotEmpty) {
      _foodId = foods.first.id;
    }
    _quantity.text = formatQuantity(_max(goal));
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  FoodItem? get _food =>
      _foodId == null ? null : _repository.fridge.itemById(_foodId!);

  /// Most the donor can give: what is still needed, and what they have.
  double _max(DonationGoal goal) {
    final food = _food;
    if (food == null) {
      return goal.remaining;
    }
    final have = convertQuantity(food.quantity, food.unit, goal.unit) ?? 0;
    return have < goal.remaining ? have : goal.remaining;
  }

  double? get _value =>
      double.tryParse(_quantity.text.trim().replaceAll(',', '.'));

  void _choose(String? foodId, DonationGoal goal) {
    setState(() {
      _foodId = foodId;
      _error = null;
      _quantity.text = formatQuantity(_max(goal));
    });
  }

  void _step(DonationGoal goal, double delta) {
    final current = _value ?? 0;
    var next = ((current + delta) * 1000).roundToDouble() / 1000;
    final max = _max(goal);
    if (next > max) next = max;
    if (next < 0) next = 0;
    setState(() {
      _error = null;
      _quantity.text = formatQuantity(next);
    });
  }

  void _confirm(DonationGoal goal) {
    final quantity = _value;
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Enter a quantity greater than 0');
      return;
    }
    if (quantity > _max(goal) + 0.0001) {
      setState(
        () =>
            _error = 'At most ${formatQuantity(_max(goal))} ${goal.unit} here',
      );
      return;
    }
    try {
      _repository.contribute(
        goal.id,
        quantity: quantity,
        donorName: widget.donorName,
        foodId: _foodId,
      );
    } on ArgumentError catch (error) {
      setState(() => _error = error.message.toString());
      return;
    } on StateError catch (error) {
      setState(() => _error = error.message);
      return;
    }
    final updated = _repository.goalById(goal.id)!;
    final given = '${formatQuantity(quantity)} ${goal.unit}';
    Navigator.of(context).pop(
      updated.isReached
          ? 'Goal reached thanks to you! ${updated.restaurantName} has '
                'everything it needed.'
          : 'You gave $given to ${updated.restaurantName}. '
                '${updated.percent}% collected.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final goal = _repository.goalById(widget.goalId)!;
    final foods = _repository.fridgeFoodsFor(goal);
    final step = quantityStepFor(goal.unit);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        22 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Give to ${goal.restaurantName}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1B1B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${goal.title} · ${formatQuantity(goal.remaining)} ${goal.unit} '
              'still needed',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            GoalProgressBar(goal: goal),
            const SizedBox(height: 18),
            const Text(
              'What do you give?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final food in foods)
                  ChoiceChip(
                    key: ValueKey('goal-source-${food.id}'),
                    selected: _foodId == food.id,
                    onSelected: (_) => _choose(food.id, goal),
                    avatar: Icon(food.category.icon, size: 18),
                    label: Text(
                      '${food.name} · ${quantityLabel(food)} · '
                      '${daysLeftLabel(food, _repository.now)}',
                    ),
                    selectedColor: const Color(0xFFC8E6C9),
                    backgroundColor: Colors.white,
                  ),
                ChoiceChip(
                  key: const ValueKey('goal-source-other'),
                  selected: _foodId == null,
                  onSelected: (_) => _choose(null, goal),
                  avatar: const Icon(Icons.shopping_bag_outlined, size: 18),
                  label: const Text('Food not in my fridge'),
                  selectedColor: const Color(0xFFC8E6C9),
                  backgroundColor: Colors.white,
                ),
              ],
            ),
            if (foods.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'No ${goal.foodName.toLowerCase()} in your fridge: you can '
                'still bring some you buy.',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                _RoundButton(
                  key: const ValueKey('goal-quantity-minus'),
                  icon: Icons.remove_rounded,
                  onPressed: () => _step(goal, -step),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const ValueKey('goal-quantity-field'),
                    controller: _quantity,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onChanged: (_) => setState(() => _error = null),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      suffixText: goal.unit,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _RoundButton(
                  key: const ValueKey('goal-quantity-plus'),
                  icon: Icons.add_rounded,
                  onPressed: () => _step(goal, step),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _food == null
                  ? 'Up to ${formatQuantity(_max(goal))} ${goal.unit}.'
                  : 'Up to ${formatQuantity(_max(goal))} ${goal.unit}. '
                        'It leaves your fridge.',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const ValueKey('goal-contribution-error'),
                style: const TextStyle(
                  color: Color(0xFFC62828),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                key: const ValueKey('confirm-contribution-button'),
                onPressed: () => _confirm(goal),
                icon: const Icon(Icons.volunteer_activism_rounded),
                label: Text(
                  'Give ${_quantity.text.isEmpty ? '' : '${_quantity.text} '}'
                  '${goal.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF2E7D32)),
      ),
    );
  }
}
