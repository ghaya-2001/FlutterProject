import 'package:flutter/material.dart';

import '../../domain/food_item.dart';
import '../../domain/fridge_formatters.dart';

/// Asks how much of [item] was eaten. Returns the amount, or null if cancelled.
Future<double?> showConsumeDialog(BuildContext context, FoodItem item) {
  return showDialog<double>(
    context: context,
    builder: (context) => _ConsumeDialog(item: item),
  );
}

class _ConsumeDialog extends StatefulWidget {
  const _ConsumeDialog({required this.item});

  final FoodItem item;

  @override
  State<_ConsumeDialog> createState() => _ConsumeDialogState();
}

class _ConsumeDialogState extends State<_ConsumeDialog> {
  late final double _step = quantityStepFor(widget.item.unit);
  late double _amount = _step < widget.item.quantity
      ? _step
      : widget.item.quantity;

  double get _remaining {
    final remaining = widget.item.quantity - _amount;
    return remaining < 0 ? 0 : (remaining * 1000).roundToDouble() / 1000;
  }

  void _change(int direction) {
    setState(() {
      final next = _amount + _step * direction;
      if (next >= widget.item.quantity) {
        _amount = widget.item.quantity;
      } else if (next < _step) {
        _amount = _step < widget.item.quantity ? _step : widget.item.quantity;
      } else {
        _amount = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isAll = _amount >= item.quantity;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Consume ${item.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'In stock: ${quantityLabel(item)}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F9F3),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('consume-decrease'),
                  onPressed: _amount > _step ? () => _change(-1) : null,
                  icon: const Icon(Icons.remove_rounded),
                  color: const Color(0xFF2E7D32),
                ),
                Expanded(
                  child: Text(
                    '${formatQuantity(_amount)} ${item.unit}',
                    key: const ValueKey('consume-amount'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('consume-increase'),
                  onPressed: isAll ? null : () => _change(1),
                  icon: const Icon(Icons.add_rounded),
                  color: const Color(0xFF2E7D32),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: isAll
                  ? null
                  : () => setState(() => _amount = item.quantity),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Finished it all'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
              ),
            ),
          ),
          Text(
            isAll
                ? 'The food will be removed from your fridge.'
                : 'Remaining after: ${formatQuantity(_remaining)} ${item.unit}',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_amount),
          child: const Text(
            'Consume',
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
