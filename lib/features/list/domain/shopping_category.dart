import 'package:flutter/material.dart';

class ShoppingCategory {
  const ShoppingCategory({
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
      other is ShoppingCategory &&
      other.name.toLowerCase() == name.toLowerCase();

  @override
  int get hashCode => name.toLowerCase().hashCode;
}

const otherShoppingCategory = ShoppingCategory(
  name: 'Other',
  icon: Icons.shopping_basket_rounded,
  color: Color(0xFFE8F5E9),
);

const defaultShoppingCategories = <ShoppingCategory>[
  ShoppingCategory(name: 'Fruits', icon: Icons.apple, color: Color(0xFFFFAB91)),
  ShoppingCategory(
    name: 'Vegetables',
    icon: Icons.eco_rounded,
    color: Color(0xFF8BC34A),
  ),
  ShoppingCategory(
    name: 'Dairy',
    icon: Icons.local_drink_rounded,
    color: Color(0xFFB3E5FC),
  ),
  ShoppingCategory(
    name: 'Meat & Fish',
    icon: Icons.set_meal_rounded,
    color: Color(0xFFFFCC80),
  ),
  ShoppingCategory(
    name: 'Bakery',
    icon: Icons.bakery_dining_rounded,
    color: Color(0xFFFFE082),
  ),
  ShoppingCategory(
    name: 'Pantry',
    icon: Icons.rice_bowl_rounded,
    color: Color(0xFFFFF59D),
  ),
  ShoppingCategory(
    name: 'Beverages',
    icon: Icons.local_cafe_rounded,
    color: Color(0xFFB2DFDB),
  ),
  ShoppingCategory(
    name: 'Frozen',
    icon: Icons.ac_unit_rounded,
    color: Color(0xFFE0F7FA),
  ),
  ShoppingCategory(
    name: 'Household',
    icon: Icons.cleaning_services_rounded,
    color: Color(0xFFD1C4E9),
  ),
  otherShoppingCategory,
];

/// Colors cycled through when the user creates their own categories.
const customCategoryColors = <Color>[
  Color(0xFFB9FBC0),
  Color(0xFFFFE082),
  Color(0xFFB2DFDB),
  Color(0xFFFFCC80),
  Color(0xFFB3E5FC),
  Color(0xFFFFAB91),
];
