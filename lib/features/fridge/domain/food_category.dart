import 'package:flutter/material.dart';

class FoodCategory {
  const FoodCategory({
    required this.name,
    required this.icon,
    required this.color,
    this.isCustom = false,
  });

  final String name;
  final IconData icon;
  final Color color;
  final bool isCustom;

  @override
  bool operator ==(Object other) =>
      other is FoodCategory && other.name.toLowerCase() == name.toLowerCase();

  @override
  int get hashCode => name.toLowerCase().hashCode;
}

const otherFoodCategory = FoodCategory(
  name: 'Other',
  icon: Icons.kitchen_rounded,
  color: Color(0xFFE8F5E9),
);

const defaultFoodCategories = <FoodCategory>[
  FoodCategory(name: 'Fruits', icon: Icons.apple, color: Color(0xFFFFF59D)),
  FoodCategory(
    name: 'Vegetables',
    icon: Icons.eco_rounded,
    color: Color(0xFF8BC34A),
  ),
  FoodCategory(
    name: 'Dairy',
    icon: Icons.local_drink_rounded,
    color: Color(0xFFFFCC80),
  ),
  FoodCategory(
    name: 'Meat & Fish',
    icon: Icons.set_meal_rounded,
    color: Color(0xFFFFAB91),
  ),
  FoodCategory(
    name: 'Bakery',
    icon: Icons.bakery_dining_rounded,
    color: Color(0xFFFFE082),
  ),
  FoodCategory(
    name: 'Pantry',
    icon: Icons.rice_bowl_rounded,
    color: Color(0xFFD7CCC8),
  ),
  FoodCategory(
    name: 'Beverages',
    icon: Icons.local_cafe_rounded,
    color: Color(0xFFB3E5FC),
  ),
  FoodCategory(
    name: 'Frozen',
    icon: Icons.ac_unit_rounded,
    color: Color(0xFFE0F7FA),
  ),
  FoodCategory(
    name: 'Leftovers',
    icon: Icons.takeout_dining_rounded,
    color: Color(0xFFB2DFDB),
  ),
  otherFoodCategory,
];

/// Colors cycled through when the user creates their own categories.
const customFoodCategoryColors = <Color>[
  Color(0xFFB9FBC0),
  Color(0xFFFFE082),
  Color(0xFFB2DFDB),
  Color(0xFFFFCC80),
  Color(0xFFB3E5FC),
  Color(0xFFFFAB91),
];
