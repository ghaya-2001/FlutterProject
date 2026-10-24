import 'package:flutter/material.dart';

import '../data/fridge_repository.dart';
import '../domain/food_item.dart';
import 'widgets/food_form.dart';
import 'widgets/fridge_form_page.dart';

/// Edits an existing food. Pops with the food name once saved.
class EditFoodScreen extends StatelessWidget {
  const EditFoodScreen({
    super.key,
    required this.repository,
    required this.item,
  });

  final FridgeRepository repository;
  final FoodItem item;

  @override
  Widget build(BuildContext context) {
    return FridgeFormPage(
      title: 'Edit food',
      bannerLabel: 'Updating',
      bannerTitle: item.name,
      bannerIcon: Icons.edit_note_rounded,
      child: FoodForm(
        repository: repository,
        initialItem: item,
        submitLabel: 'Save changes',
        submitIcon: Icons.check_rounded,
        onSubmit: (values) {
          repository.updateFood(
            item.copyWith(
              name: values.name,
              category: values.category,
              quantity: values.quantity,
              unit: values.unit,
              expiryDate: values.expiryDate,
              note: values.note,
            ),
          );
          Navigator.of(context).pop(values.name);
        },
      ),
    );
  }
}
