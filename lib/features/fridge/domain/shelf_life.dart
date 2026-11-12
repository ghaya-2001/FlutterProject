import 'package:flutter/material.dart';

import 'food_category.dart';

/// Typical number of days a food keeps in the fridge, per category.
/// Used to suggest an expiry date for groceries coming from the shopping list.
const shelfLifeDays = <String, int>{
  'Fruits': 7,
  'Vegetables': 5,
  'Dairy': 7,
  'Meat & Fish': 2,
  'Bakery': 3,
  'Pantry': 180,
  'Beverages': 30,
  'Frozen': 90,
  'Leftovers': 3,
};

/// Default for custom categories and "Other".
const defaultShelfLifeDays = 14;

/// Shopping categories that are not food and never go to the fridge.
const nonFoodShoppingCategories = <String>{'Household'};

DateTime suggestedExpiry(FoodCategory category, DateTime boughtOn) {
  final days = shelfLifeDays[category.name] ?? defaultShelfLifeDays;
  return DateUtils.addDaysToDate(DateUtils.dateOnly(boughtOn), days);
}
