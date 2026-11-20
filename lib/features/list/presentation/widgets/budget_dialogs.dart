import 'package:flutter/material.dart';

import '../../domain/budget.dart';

/// Result of [showBudgetDialog].
class BudgetDialogResult {
  const BudgetDialogResult.save(this.amount, this.period) : remove = false;

  const BudgetDialogResult.remove()
    : amount = 0,
      period = BudgetPeriod.monthly,
      remove = true;

  final double amount;
  final BudgetPeriod period;

  /// True when the user chose "Remove budget".
  final bool remove;
}

/// Asks for the budget amount and whether it is weekly or monthly.
Future<BudgetDialogResult?> showBudgetDialog(
  BuildContext context, {
  ShoppingBudget? current,
}) {
  return showDialog<BudgetDialogResult>(
    context: context,
    builder: (context) => _BudgetDialog(current: current),
  );
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({this.current});

  final ShoppingBudget? current;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  late BudgetPeriod _period;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _controller = TextEditingController(
      text: current == null ? '' : current.amount.toStringAsFixed(2),
    );
    _period = current?.period ?? BudgetPeriod.monthly;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final amount = parsePrice(_controller.text)!;
    Navigator.of(context).pop(BudgetDialogResult.save(amount, _period));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.current == null ? 'Set your budget' : 'Edit budget'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<BudgetPeriod>(
              segments: const [
                ButtonSegment(
                  value: BudgetPeriod.weekly,
                  label: Text('Weekly'),
                ),
                ButtonSegment(
                  value: BudgetPeriod.monthly,
                  label: Text('Monthly'),
                ),
              ],
              selected: {_period},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _period = selection.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: const Color(0xFFB9FBC0),
                selectedForegroundColor: const Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('budget-amount-field'),
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _moneyDecoration(
                _period == BudgetPeriod.weekly
                    ? 'Food budget per week'
                    : 'Food budget per month',
              ),
              validator: (value) {
                try {
                  final amount = parsePrice(value ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Enter an amount greater than 0';
                  }
                } on FormatException {
                  return 'Enter a valid amount';
                }
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            key: const ValueKey('remove-budget-button'),
            onPressed: () =>
                Navigator.of(context).pop(const BudgetDialogResult.remove()),
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFC62828)),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
        ),
        TextButton(
          key: const ValueKey('save-budget-button'),
          onPressed: _save,
          child: const Text(
            'Save',
            style: TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Result of [showPriceDialog]: the new amount (null = no price).
class PriceDialogResult {
  const PriceDialogResult(this.amount);

  final double? amount;
}

/// Asks what was really paid for [itemName]. An empty field means "no price".
Future<PriceDialogResult?> showPriceDialog(
  BuildContext context, {
  required String itemName,
  double? current,
}) {
  return showDialog<PriceDialogResult>(
    context: context,
    builder: (context) => _PriceDialog(itemName: itemName, current: current),
  );
}

class _PriceDialog extends StatefulWidget {
  const _PriceDialog({required this.itemName, this.current});

  final String itemName;
  final double? current;

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.current == null ? '' : widget.current!.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(PriceDialogResult(parsePrice(_controller.text)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Price paid for ${widget.itemName}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const ValueKey('purchase-price-field'),
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _moneyDecoration('Total paid (leave empty if unknown)'),
          validator: (value) {
            try {
              parsePrice(value ?? '');
            } on FormatException {
              return 'Enter a valid amount';
            }
            return null;
          },
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
        ),
        TextButton(
          key: const ValueKey('save-price-button'),
          onPressed: _save,
          child: const Text(
            'Save',
            style: TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

InputDecoration _moneyDecoration(String label) {
  return InputDecoration(
    labelText: label,
    suffixText: budgetCurrency,
    prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF2E7D32)),
    filled: true,
    fillColor: const Color(0xFFF5F9F3),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
  );
}
