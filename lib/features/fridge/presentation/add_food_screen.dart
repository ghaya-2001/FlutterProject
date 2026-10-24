import 'package:flutter/material.dart';

import '../data/fridge_repository.dart';
import 'widgets/food_form.dart';
import 'widgets/fridge_form_page.dart';

/// Adds a new food to the fridge. Pops with the food name once saved.
class AddFoodScreen extends StatelessWidget {
  const AddFoodScreen({super.key, required this.repository});

  final FridgeRepository repository;

  @override
  Widget build(BuildContext context) {
    return FridgeFormPage(
      title: 'Add food',
      bannerLabel: 'Stock up your fridge',
      bannerTitle: 'What did you buy?',
      bannerIcon: Icons.kitchen_rounded,
      child: FoodForm(
        repository: repository,
        submitLabel: 'Add to fridge',
        submitIcon: Icons.add_rounded,
        onSubmit: (values) {
          final item = repository.addFood(
            name: values.name,
            category: values.category,
            quantity: values.quantity,
            unit: values.unit,
            expiryDate: values.expiryDate,
            note: values.note,
          );
          Navigator.of(context).pop(item.name);
        },
      ),
    );
  }
}
