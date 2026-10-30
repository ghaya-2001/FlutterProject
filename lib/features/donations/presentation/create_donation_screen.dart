import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../fridge/domain/food_item.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../data/donation_repository.dart';

/// Creates a donation from a food in the fridge.
///
/// Pops with the food name once the donation is created.
class CreateDonationScreen extends StatefulWidget {
  const CreateDonationScreen({
    super.key,
    required this.repository,
    this.initialFoodId,
  });

  final DonationRepository repository;

  /// Food selected when the screen opens (e.g. from Food Details).
  final String? initialFoodId;

  @override
  State<CreateDonationScreen> createState() => _CreateDonationScreenState();
}

class _CreateDonationScreenState extends State<CreateDonationScreen> {
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();
  FoodItem? _food;
  DateTime? _expiryDate;
  String? _error;

  DonationRepository get _repository => widget.repository;

  @override
  void initState() {
    super.initState();
    final foods = _repository.donatableFoods;
    FoodItem? initial;
    for (final food in foods) {
      if (food.id == widget.initialFoodId) {
        initial = food;
      }
    }
    _selectFood(initial ?? (foods.isEmpty ? null : foods.first));
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _selectFood(FoodItem? food) {
    _food = food;
    _error = null;
    if (food != null) {
      // By default the whole quantity is offered until the fridge date.
      _quantityController.text = formatQuantity(food.quantity);
      _expiryDate = DateUtils.dateOnly(food.expiryDate);
    }
  }

  void _changeQuantity(int direction) {
    final food = _food;
    if (food == null) {
      return;
    }
    final current = double.tryParse(_quantityController.text) ?? 0;
    final step = quantityStepFor(food.unit);
    var next = current + direction * step;
    if (next > food.quantity) {
      next = food.quantity;
    }
    if (next <= 0) {
      return;
    }
    setState(() {
      _error = null;
      _quantityController.text = formatQuantity(next);
    });
  }

  Future<void> _pickDate() async {
    final food = _food;
    if (food == null) {
      return;
    }
    final today = DateUtils.dateOnly(_repository.now);
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? food.expiryDate,
      firstDate: today,
      // The fridge expiry date is the limit: a donation can't last longer.
      lastDate: DateUtils.dateOnly(food.expiryDate),
      helpText: 'Consume before',
    );
    if (picked != null && mounted) {
      setState(() => _expiryDate = DateUtils.dateOnly(picked));
    }
  }

  void _submit() {
    final food = _food;
    final date = _expiryDate;
    if (food == null || date == null) {
      return;
    }
    final quantity = double.tryParse(
      _quantityController.text.replaceAll(',', '.'),
    );
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Enter a quantity greater than 0');
      return;
    }
    if (quantity > food.quantity) {
      setState(
        () => _error = 'You only have ${quantityLabel(food)} in your fridge',
      );
      return;
    }
    _repository.createDonation(
      foodId: food.id,
      quantity: quantity,
      expiryDate: date,
      description: _descriptionController.text,
    );
    Navigator.of(context).pop(food.name);
  }

  @override
  Widget build(BuildContext context) {
    final foods = _repository.donatableFoods;
    final food = _food;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          children: [
            const ScreenHeader(title: 'New donation'),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB7E4C7), Color(0xFFE9F7EC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.volunteer_activism_rounded,
                    size: 36,
                    color: Color(0xFF2E7D32),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Share food you won\'t eat in time with a partner '
                      'restaurant or a local charity.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF1B1B1B)),
                    ),
                  ),
                ],
              ),
            ),
            if (food == null) ...[
              const SizedBox(height: 22),
              const EmptyCard(
                icon: Icons.kitchen_outlined,
                message:
                    'Your fridge has no food that can be donated. '
                    'Expired food cannot be donated.',
              ),
            ] else ...[
              const _Label('Food from your fridge'),
              DropdownButtonFormField<String>(
                key: const ValueKey('donation-food-field'),
                initialValue: food.id,
                isExpanded: true,
                decoration: _decoration(Icons.kitchen_rounded),
                items: [
                  for (final item in foods)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        '${item.name} · ${quantityLabel(item)} · '
                        '${daysLeftLabel(item, _repository.now)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) => setState(
                  () => _selectFood(foods.firstWhere((item) => item.id == id)),
                ),
              ),
              _Label('Quantity (max ${quantityLabel(food)})'),
              Row(
                children: [
                  _RoundButton(
                    icon: Icons.remove_rounded,
                    onPressed: () => _changeQuantity(-1),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('donation-quantity-field'),
                      controller: _quantityController,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() => _error = null),
                      decoration: _decoration(Icons.scale_rounded)
                          .copyWith(suffixText: food.unit, errorText: _error),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RoundButton(
                    icon: Icons.add_rounded,
                    onPressed: () => _changeQuantity(1),
                  ),
                ],
              ),
              const _Label('Consume before'),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_rounded, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          formatDate(_expiryDate ?? food.expiryDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Text(
                        'Change',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Fridge expiry date: ${formatDate(food.expiryDate)} '
                  '(a donation can\'t go beyond it).',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              const _Label('Description (optional)'),
              TextField(
                key: const ValueKey('donation-description-field'),
                controller: _descriptionController,
                maxLines: 3,
                decoration: _decoration(
                  Icons.notes_rounded,
                ).copyWith(hintText: 'e.g. unopened pack, keep refrigerated'),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  key: const ValueKey('publish-donation-button'),
                  onPressed: _submit,
                  icon: const Icon(Icons.volunteer_activism_rounded),
                  label: const Text(
                    'Publish donation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(IconData icon) {
    return InputDecoration(
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1B1B1B),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE8F5E9),
      borderRadius: BorderRadius.circular(16),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF2E7D32)),
      ),
    );
  }
}
